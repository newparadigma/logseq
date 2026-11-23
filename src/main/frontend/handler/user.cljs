(ns frontend.handler.user
  "Sign-in with a token issued for the self-hosted sync server, logout and
  user info read from that token."
  (:require [cljs-time.coerce :as tc]
            [cljs-time.core :as t]
            [clojure.string :as string]
            [electron.ipc :as ipc]
            [frontend.common.thread-api :refer [def-thread-api]]
            [frontend.config :as config]
            [frontend.state :as state]
            [frontend.util :as util]
            [logseq.common.path :as path]
            [goog.crypt.base64 :as base64]
            [promesa.core :as p]))

(defn- decode-username
  [username]
  (let [arr (new js/Uint8Array (count username))]
    (doseq [i (range (count username))]
      (aset arr i (.charCodeAt username i)))
    (.decode (new js/TextDecoder "utf-8") arr)))

(defn parse-jwt [jwt]
  (some-> jwt
          (string/split ".")
          second
          (#(base64/decodeString % true))
          js/JSON.parse
          (js->clj :keywordize-keys true)
          (update :cognito:username decode-username)))

(defn- parse-jwt-safe
  [jwt]
  (try
    (parse-jwt jwt)
    (catch :default _
      nil)))

(defn- expired? [parsed-jwt]
  (some->
   (* 1000 (:exp parsed-jwt))
   tc/from-long
   (t/before? (t/now))))

(defn- valid-token?
  [parsed-jwt]
  (and (string? (:sub parsed-jwt))
       (number? (:exp parsed-jwt))
       (not (expired? parsed-jwt))))

(defn email []
  (some->
   (state/get-auth-id-token)
   parse-jwt
   :email))

(defn username []
  (some->
   (state/get-auth-id-token)
   parse-jwt
   :cognito:username))

(defn user-uuid []
  (some->
   (state/get-auth-id-token)
   parse-jwt
   :sub))

(defn logged-in? []
  (let [token (state/get-auth-refresh-token)]
    (when (string? token)
      (not (string/blank? token)))))

(defn- set-token-to-localstorage!
  [id-token access-token refresh-token]
  (js/localStorage.setItem "id-token" id-token)
  (js/localStorage.setItem "access-token" access-token)
  (js/localStorage.setItem "refresh-token" refresh-token))

(defn- auth-file-path
  []
  (when-let [home-dir (state/get-state [:system/info :home-dir])]
    (path/path-join home-dir "logseq-dev" "auth.json")))

(defn- auth-file-payload
  []
  {:id-token (state/get-auth-id-token)
   :access-token (state/get-state :auth/access-token)
   :refresh-token (state/get-auth-refresh-token)
   :updated-at (.now js/Date)})

(defn- persist-auth-file!
  []
  (when (util/electron?)
    (when-let [auth-path (auth-file-path)]
      (-> (ipc/ipc "writeFile"
                   nil
                   auth-path
                   (js/JSON.stringify (clj->js (auth-file-payload)) nil 2))
          (p/catch (fn [error]
                     (js/console.warn :persist-auth-file-failed error)
                     nil))))))

(defn- clear-tokens
  []
  (state/set-auth-id-token nil)
  (state/set-auth-access-token nil)
  (state/set-auth-refresh-token nil)
  (set-token-to-localstorage! "" "" "")
  (persist-auth-file!))

(defn- set-token!
  "The sign-in token has no refresh token. It is stored in all three token
  slots: the refresh-token slot marks the session as logged in, and the E2EE
  password stored on this device is encrypted with it."
  [token]
  (let [user (parse-jwt token)]
    (state/set-auth-id-token token (:sub user))
    (state/set-auth-access-token token)
    (state/set-auth-refresh-token token)
    (set-token-to-localstorage! token token token)
    (persist-auth-file!)
    (state/set-state! :auth/current-login-user user)))

(defn restore-tokens-from-localstorage
  "Restore the saved sign-in token. An expired token is removed."
  []
  (let [token (js/localStorage.getItem "id-token")]
    (when (and (string? token) (not (string/blank? token)))
      (if (valid-token? (parse-jwt-safe token))
        (do
          (set-token! token)
          (state/pub-event! [:user/fetch-info-and-graphs]))
        (clear-tokens)))))

(defn login-with-self-hosted-token!
  "Sign in with a token issued for the self-hosted sync server
  (deps/db-sync/scripts/selfhost-token.mjs). Returns false when the token
  does not parse, has no `sub` or is expired."
  [token]
  (if (valid-token? (parse-jwt-safe token))
    (do
      (set-token! token)
      (state/pub-event! [:user/fetch-info-and-graphs])
      true)
    false))

(defn- clear-e2ee-password!
  []
  (when @state/*db-worker
    (-> (state/<invoke-db-worker :thread-api/clear-e2ee-password)
        (p/catch (fn [error]
                   (js/console.warn :clear-e2ee-password-failed error)
                   nil)))))

(defn logout []
  (clear-e2ee-password!)
  (clear-tokens)
  (.clear js/localStorage)
  (state/set-state! :auth/current-login-user :logout))

(defn <ensure-id&access-token!
  "Tokens are not refreshed: an empty or expired token logs the user out."
  []
  (let [id-token (state/get-auth-id-token)]
    (if (and id-token (valid-token? (parse-jwt-safe id-token)))
      (p/resolved nil)
      (do
        (clear-tokens)
        (p/rejected (ex-info "empty or expired token" {:type :expired-token}))))))

(def-thread-api :thread-api/ensure-id&access-token
  []
  (p/let [_ (<ensure-id&access-token!)]
    {:id-token (state/get-auth-id-token)}))

(defn rtc-group?
  "The sync (RTC) UI needs a sync server; there is no default one."
  []
  (some? (config/get-custom-sync-server-url)))

(defn can-list-remote-graphs?
  "True when a logged-in user can fetch and display remote/synced graphs."
  []
  (boolean (and (logged-in?) (rtc-group?))))

(defn get-user-type
  [repo]
  (-> (some #(when (= repo (:url %)) %) (:rtc/graphs (state/get-state)))
      :graph<->user-user-type))

(defn manager?
  [repo]
  (= (get-user-type repo) "manager"))
