(ns frontend.handler.user-test
  (:require [cljs.test :refer [deftest is testing]]
            [electron.ipc :as ipc]
            [frontend.config :as config]
            [frontend.handler.user :as user-handler]
            [frontend.state :as state]
            [frontend.util :as util]
            [promesa.core :as p]))

(defn- with-mocked-local-storage
  ([f]
   (with-mocked-local-storage {} f))
  ([items f]
   (let [old-storage (.-localStorage js/globalThis)
         had-local-storage?
         (.call (.-hasOwnProperty (.-prototype js/Object))
                js/globalThis
                "localStorage")
         mocked-storage #js {:clear (fn [] nil)
                             :setItem (fn [& _] nil)
                             :getItem (fn [k] (get items k))
                             :removeItem (fn [& _] nil)}]
     (js/Object.defineProperty js/globalThis
                               "localStorage"
                               #js {:value mocked-storage
                                    :configurable true
                                    :writable true})
     (try
       (f)
       (finally
         (if had-local-storage?
           (js/Object.defineProperty js/globalThis
                                     "localStorage"
                                     #js {:value old-storage
                                          :configurable true
                                          :writable true})
           (js/Reflect.deleteProperty js/globalThis "localStorage")))))))

(defn- jwt
  [payload]
  (str "header."
       (js/btoa (js/JSON.stringify (clj->js (merge {:cognito:username ""} payload))))
       ".sig"))

(def ^:private far-future-exp 4102444800)

(deftest set-token-persists-auth-json-with-token-in-all-slots-test
  (let [writes* (atom [])
        old-state (state/get-state)
        token (jwt {:sub "user-1" :exp far-future-exp})]
    (state/replace-state! (assoc-in old-state [:system/info :home-dir] "/tmp/home"))
    (try
      (with-mocked-local-storage
        (fn []
          (with-redefs [util/electron? (constantly true)
                        ipc/ipc (fn [op _repo path content]
                                  (is (= "writeFile" op))
                                  (swap! writes* conj {:path path
                                                       :content content})
                                  (p/resolved nil))]
            (#'user-handler/set-token! token)
            (is (= 1 (count @writes*)))
            (is (= "/tmp/home/logseq-dev/auth.json" (:path (first @writes*))))
            (is (= {:id-token token
                    :access-token token
                    :refresh-token token}
                   (select-keys (js->clj (js/JSON.parse (:content (first @writes*))) :keywordize-keys true)
                                [:id-token :access-token :refresh-token]))))))
      (finally
        (state/replace-state! old-state)))))

(deftest login-with-self-hosted-token-rejects-invalid-tokens-test
  (let [old-state (state/get-state)]
    (try
      (with-mocked-local-storage
        (fn []
          (with-redefs [util/electron? (constantly false)
                        state/pub-event! (fn [& _] (is false "no login event expected"))]
            (is (false? (user-handler/login-with-self-hosted-token! "not-a-jwt")))
            (is (false? (user-handler/login-with-self-hosted-token! (jwt {:sub "user-1" :exp 1}))))
            (is (false? (user-handler/login-with-self-hosted-token! (jwt {:exp far-future-exp}))))
            (is (nil? (state/get-auth-id-token))))))
      (finally
        (state/replace-state! old-state)))))

(deftest restore-tokens-restores-valid-token-test
  (let [old-state (state/get-state)
        events* (atom [])
        token (jwt {:sub "user-1" :exp far-future-exp})]
    (state/replace-state! (assoc old-state
                                 :auth/id-token nil
                                 :auth/access-token nil
                                 :auth/refresh-token nil))
    (try
      (with-mocked-local-storage
        {"id-token" token "access-token" token "refresh-token" token}
        (fn []
          (with-redefs [util/electron? (constantly false)
                        state/pub-event! (fn [event] (swap! events* conj event))]
            (user-handler/restore-tokens-from-localstorage)
            (is (= token (state/get-auth-id-token)))
            (is (= token (state/get-auth-refresh-token)))
            (is (= [[:user/fetch-info-and-graphs]] @events*)))))
      (finally
        (state/replace-state! old-state)))))

(deftest restore-tokens-clears-expired-token-test
  (let [old-state (state/get-state)
        expired (jwt {:sub "user-1" :exp 0})]
    (state/replace-state! (assoc old-state :auth/refresh-token expired))
    (try
      (with-mocked-local-storage
        {"id-token" expired "access-token" expired "refresh-token" expired}
        (fn []
          (with-redefs [util/electron? (constantly false)
                        state/pub-event! (fn [& _] (is false "no login event expected"))]
            (user-handler/restore-tokens-from-localstorage)
            (is (nil? (state/get-auth-id-token)))
            (is (nil? (state/get-auth-refresh-token)))
            (is (not (user-handler/logged-in?))))))
      (finally
        (state/replace-state! old-state)))))

(deftest logout-clears-e2ee-password-when-db-worker-ready-test
  (testing "logout should request db-worker to clear persisted e2ee password"
    (let [ops* (atom [])
          old-worker @state/*db-worker
          old-login-user (:auth/current-login-user (state/get-state))]
      (reset! state/*db-worker :worker)
      (try
        (with-mocked-local-storage
          (fn []
            (with-redefs [state/<invoke-db-worker (fn [op & _]
                                                    (swap! ops* conj op)
                                                    (p/resolved nil))
                          state/pub-event! (fn [& _] nil)
                          user-handler/clear-tokens (fn [] nil)]
              (user-handler/logout)
              (is (= :thread-api/clear-e2ee-password
                     (first @ops*))))))
        (finally
          (state/set-state! :auth/current-login-user old-login-user)
          (reset! state/*db-worker old-worker))))))

(deftest can-list-remote-graphs-requires-sync-server-url-test
  (with-redefs [config/get-custom-sync-server-url (constantly nil)
                user-handler/logged-in? (constantly true)]
    (is (false? (user-handler/rtc-group?)))
    (is (false? (user-handler/can-list-remote-graphs?))))
  (with-redefs [config/get-custom-sync-server-url (constantly "https://sync.example.com")
                user-handler/logged-in? (constantly true)]
    (is (true? (user-handler/rtc-group?)))
    (is (true? (user-handler/can-list-remote-graphs?)))))

(deftest logout-skips-e2ee-password-clear-when-db-worker-missing-test
  (testing "logout should not call db-worker API when db-worker is unavailable"
    (let [invoke-calls* (atom 0)
          old-worker @state/*db-worker
          old-login-user (:auth/current-login-user (state/get-state))]
      (reset! state/*db-worker nil)
      (try
        (with-mocked-local-storage
          (fn []
            (with-redefs [state/<invoke-db-worker (fn [& _]
                                                    (swap! invoke-calls* inc)
                                                    (p/resolved nil))
                          state/pub-event! (fn [& _] nil)
                          user-handler/clear-tokens (fn [] nil)]
              (user-handler/logout)
              (is (zero? @invoke-calls*)))))
        (finally
          (state/set-state! :auth/current-login-user old-login-user)
          (reset! state/*db-worker old-worker))))))
