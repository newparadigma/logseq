(ns logseq.publish.node-storage-test
  (:require ["fs" :as fs]
            ["os" :as os]
            ["path" :as node-path]
            [cljs.test :refer [async deftest is testing]]
            [logseq.publish.common :as publish-common]
            [logseq.publish.node.storage :as storage]
            [promesa.core :as p]))

(defn- temp-dir []
  (.mkdtempSync fs (node-path/join (.tmpdir os) "publish-storage-test-")))

(deftest meta-sql-exec-test
  (let [dir (temp-dir)
        ^js sql (storage/open-meta-sql dir)]
    (publish-common/sql-exec sql "CREATE TABLE t (a TEXT, b TEXT);")
    (testing "undefined binds as NULL, like on Cloudflare"
      (publish-common/sql-exec sql "INSERT INTO t (a, b) VALUES (?, ?);" "x" js/undefined))
    (is (= [{:a "x" :b nil}]
           (js->clj (publish-common/get-sql-rows (publish-common/sql-exec sql "SELECT a, b FROM t;"))
                    :keywordize-keys true)))
    (testing "PRAGMA returns rows"
      (is (= ["a" "b"]
             (map #(aget % "name")
                  (publish-common/get-sql-rows (publish-common/sql-exec sql "PRAGMA table_info(t);"))))))
    (.close sql)
    (.rmSync fs dir #js {:recursive true :force true})))

(deftest bucket-round-trip-test
  (async done
         (let [dir (temp-dir)
               ^js bucket (storage/make-bucket dir)
               payload (.-buffer (.encode (js/TextEncoder.) "hello"))]
           (-> (p/let [missing (.head bucket "publish/g/a.png")
                       _ (.put bucket "publish/g/a.png" payload
                               #js {:httpMetadata #js {:contentType "image/png"}
                                    :customMetadata #js {:checksum "c1"}})
                       ^js head (.head bucket "publish/g/a.png")
                       ^js object (.get bucket "publish/g/a.png")
                       buf (.arrayBuffer object)]
                 (is (nil? missing))
                 (is (= "c1" (.. head -customMetadata -checksum)))
                 (is (= "image/png" (.. object -httpMetadata -contentType)))
                 (is (= "hello" (.decode (js/TextDecoder.) buf))))
               (p/catch (fn [e] (is false (str e))))
               (p/finally (fn []
                            (.rmSync fs dir #js {:recursive true :force true})
                            (done)))))))

(deftest bucket-delete-and-list-test
  (async done
         (let [dir (temp-dir)
               ^js bucket (storage/make-bucket dir)
               payload (.-buffer (.encode (js/TextEncoder.) "x"))
               list-keys (fn [prefix]
                           (p/let [^js result (.list bucket #js {:prefix prefix})]
                             (is (false? (.-truncated result)))
                             (mapv #(.-key ^js %) (.-objects result))))]
           (-> (p/let [_ (p/all (map #(.put bucket % payload #js {})
                                     ["publish/g1/a.transit"
                                      "publish/assets/g1/u1.png"
                                      "publish/assets/g1/u1@1024.png"
                                      "publish/assets/g1/u2.png"
                                      "publish/assets/g2/u1.png"]))
                       graph-assets (list-keys "publish/assets/g1/")
                       asset-variants (list-keys "publish/assets/g1/u1")
                       missing-dir (list-keys "publish/assets/g3/")
                       _ (.delete bucket "publish/assets/g1/u1.png")
                       _ (.delete bucket "publish/assets/g1/never-stored.png")
                       deleted (.head bucket "publish/assets/g1/u1.png")
                       after-delete (list-keys "publish/assets/g1/")]
                 (is (= ["publish/assets/g1/u1.png" "publish/assets/g1/u1@1024.png" "publish/assets/g1/u2.png"]
                        graph-assets))
                 (is (= ["publish/assets/g1/u1.png" "publish/assets/g1/u1@1024.png"] asset-variants))
                 (is (= [] missing-dir))
                 (is (nil? deleted))
                 (is (not (.existsSync fs (node-path/join dir "publish/assets/g1/u1.png.meta.json"))))
                 (is (= ["publish/assets/g1/u1@1024.png" "publish/assets/g1/u2.png"] after-delete)))
               (p/catch (fn [e] (is false (str e))))
               (p/finally (fn []
                            (.rmSync fs dir #js {:recursive true :force true})
                            (done)))))))

(deftest bucket-rejects-keys-outside-base-dir-test
  (let [dir (temp-dir)
        ^js bucket (storage/make-bucket dir)]
    (doseq [bad-key ["../x" "publish/assets/../../../x" "publish/a.png.meta.json"]]
      (is (thrown-with-msg? js/Error #"invalid object key" (.get bucket bad-key)) bad-key)
      (is (thrown-with-msg? js/Error #"invalid object key" (.delete bucket bad-key)) bad-key))
    (is (thrown-with-msg? js/Error #"invalid object key" (.list bucket #js {:prefix "../../"})))
    (.rmSync fs dir #js {:recursive true :force true})))
