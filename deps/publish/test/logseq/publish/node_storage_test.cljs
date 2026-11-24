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

(deftest bucket-rejects-keys-outside-base-dir-test
  (let [dir (temp-dir)
        ^js bucket (storage/make-bucket dir)]
    (doseq [bad-key ["../x" "publish/assets/../../../x" "publish/a.png.meta.json"]]
      (is (thrown-with-msg? js/Error #"invalid object key" (.get bucket bad-key)) bad-key))
    (.rmSync fs dir #js {:recursive true :force true})))
