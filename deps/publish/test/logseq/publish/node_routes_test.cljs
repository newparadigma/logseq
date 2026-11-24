(ns logseq.publish.node-routes-test
  "Publish routes against the Node stand-ins (SQLite metadata, file bucket)."
  (:require ["fs" :as fs]
            ["os" :as os]
            ["path" :as node-path]
            [cljs.test :refer [async deftest is]]
            [logseq.common.authorization :as authorization]
            [logseq.db :as ldb]
            [logseq.publish.common :as publish-common]
            [logseq.publish.meta-store :as meta-store]
            [logseq.publish.node.storage :as storage]
            [logseq.publish.routes :as routes]
            [promesa.core :as p]))

(def graph "00000000-0000-0000-0000-00000000000g")
(def page-1 #uuid "00000000-0000-0000-0000-000000000001")
(def page-2 #uuid "00000000-0000-0000-0000-000000000002")
(def shared-asset #uuid "00000000-0000-0000-0000-0000000000a1")
(def own-asset #uuid "00000000-0000-0000-0000-0000000000a2")

(defn- make-env [dir]
  (let [^js sql (storage/open-meta-sql dir)
        self #js {:sql sql}]
    #js {"PUBLISH_META_DO" #js {:idFromName identity
                                :get (fn [_id]
                                       #js {:fetch (fn [url init]
                                                     (meta-store/do-fetch self (js/Request. url init)))})}
         "PUBLISH_R2" (storage/make-bucket (node-path/join dir "objects"))
         :sql sql}))

(defn- page-body
  "Transit body of a page with one block and the given asset blocks."
  [page-uuid title asset-uuids]
  (let [datoms (concat [[1 :block/uuid page-uuid 1 true]
                        [1 :block/title title 1 true]
                        [2 :block/uuid (random-uuid) 1 true]
                        [2 :block/page 1 1 true]
                        [2 :block/title (str title " text") 1 true]]
                       (mapcat (fn [i asset-uuid]
                                 [[i :block/uuid asset-uuid 1 true]
                                  [i :block/page 1 1 true]
                                  [i :logseq.property.asset/type "png" 1 true]])
                               (range 10 20)
                               asset-uuids))]
    (ldb/write-transit-str {:page-uuid page-uuid
                            :datoms (vec datoms)
                            :blocks [{:page_uuid (str page-uuid)
                                      :block_uuid (str (random-uuid))
                                      :block_content (str title " text")}]})))

(defn- publish! [env page-uuid title asset-uuids]
  (let [body (page-body page-uuid title asset-uuids)
        content-hash (str (hash body))]
    (routes/handle-fetch
     (js/Request. "https://publish.example/pages"
                  #js {:method "POST"
                       :headers #js {"authorization" "Bearer token"
                                     "x-publish-meta"
                                     (js/JSON.stringify
                                      #js {:graph graph
                                           :page_uuid (str page-uuid)
                                           :content_hash content-hash
                                           ;; Ignored: the owner comes from the token
                                           :owner_sub "spoofed"
                                           :owner_username "spoofed"})}
                       :body body})
     env)))

(defn- delete! [env path]
  (routes/handle-fetch (js/Request. (str "https://publish.example" path)
                                    #js {:method "DELETE"
                                         :headers #js {"authorization" "Bearer token"}})
                       env))

(defn- stored-keys [env]
  (p/let [^js result (.list (aget env "PUBLISH_R2") #js {:prefix "publish/"})]
    (set (map #(.-key ^js %) (.-objects result)))))

(defn- asset-keys [asset-uuid]
  [(str "publish/assets/" graph "/" asset-uuid ".png")
   (str "publish/assets/" graph "/" asset-uuid "@1024.png")])

(defn- put-assets! [env]
  (let [r2 (aget env "PUBLISH_R2")
        data (.-buffer (.encode publish-common/text-encoder "img"))]
    (p/all (map #(.put r2 % data #js {})
                (concat (asset-keys shared-asset)
                        (asset-keys own-asset)
                        [(str "publish/assets/" graph "/publish.css")])))))

(defn- block-count [env page-uuid]
  (-> (publish-common/sql-exec (aget env "sql")
                               "SELECT count(*) AS n FROM page_blocks WHERE page_uuid = ?;"
                               (str page-uuid))
      publish-common/get-sql-rows
      first
      (aget "n")))

(defn- transit-keys [ks]
  (set (filter #(re-find #"\.transit$" %) ks)))

(deftest publish-and-unpublish-on-node-storage-test
  (async done
         (let [dir (.mkdtempSync fs (node-path/join (.tmpdir os) "publish-routes-test-"))
               env (make-env dir)
               *claims (atom #js {"sub" "owner-a" "cognito:username" "alice"})]
           (-> (p/with-redefs [authorization/verify-jwt (fn [_ _] (p/resolved @*claims))]
                 (p/let [resp-1 (publish! env page-1 "One" [shared-asset own-asset])
                         page-2-key (-> (publish! env page-2 "Two" [shared-asset])
                                        (p/then #(.json ^js %))
                                        (p/then #(.-r2_key ^js %)))
                         _ (put-assets! env)
                         ^js meta (-> (routes/handle-fetch (js/Request. (str "https://publish.example/pages/" graph "/" page-1)) env)
                                      (p/then #(.json ^js %)))
                         keys-1 (stored-keys env)
                         transit-1 (transit-keys keys-1)

                         _ (reset! *claims #js {"sub" "owner-b" "cognito:username" "bob"})
                         foreign-resp (publish! env page-1 "Hijacked" [])
                         _ (reset! *claims #js {"sub" "owner-a" "cognito:username" "alice"})

                         _ (publish! env page-1 "One changed" [shared-asset own-asset])
                         keys-2 (stored-keys env)
                         transit-2 (transit-keys keys-2)
                         transit-resp (routes/handle-fetch
                                       (js/Request. (str "https://publish.example/pages/" graph "/" page-1 "/transit"))
                                       env)
                         transit-text (.text transit-resp)

                         blocks-before (block-count env page-1)
                         delete-1 (delete! env (str "/pages/" graph "/" page-1))
                         after-delete-1 (stored-keys env)
                         blocks-after (block-count env page-1)

                         delete-2 (delete! env (str "/pages/" graph "/" page-2))
                         after-delete-2 (stored-keys env)
                         missing-short (routes/handle-fetch (js/Request. "https://publish.example/p/nothing") env)
                         missing-short-body (.text missing-short)]
                   (is (= 200 (.-status resp-1)))
                   (is (= ["owner-a" "alice"] [(.-owner_sub meta) (.-owner_username meta)])
                       "owner comes from the token, not from the request")
                   (is (= 2 (count transit-1)))
                   (is (= 403 (.-status foreign-resp)) "another user cannot overwrite the page")
                   (is (= 2 (count transit-2)) "republishing replaces the old payload")
                   (is (not= transit-1 transit-2))
                   (is (= 200 (.-status transit-resp)))
                   (is (re-find #"One changed" transit-text))
                   (is (= 1 blocks-before))
                   (is (= 200 (.-status delete-1)))
                   (is (= (into (set (asset-keys shared-asset))
                                [(str "publish/assets/" graph "/publish.css") page-2-key])
                          after-delete-1)
                       "page-1 payload and its own assets are gone, the shared asset stays")
                   (is (= 0 blocks-after) "search rows of the unpublished page are gone")
                   (is (= 200 (.-status delete-2)))
                   (is (= #{} after-delete-2) "the last page takes all graph objects with it")
                   (is (= 404 (.-status missing-short)))
                   (is (re-find #"404" missing-short-body))
                   (is (= "text/html; charset=utf-8" (.get (.-headers missing-short) "content-type")))))
               (p/catch (fn [e] (is false (str e))))
               (p/finally (fn []
                            (.close (aget env "sql"))
                            (.rmSync fs dir #js {:recursive true :force true})
                            (done)))))))
