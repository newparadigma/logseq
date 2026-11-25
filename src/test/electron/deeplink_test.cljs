(ns electron.deeplink-test
  (:require [cljs.test :refer [deftest is testing]]
            [electron.deeplink :as deeplink]))

(deftest parse-url-test
  (testing "graph destinations are decoded and preserved"
    (doseq [host ["graph" "new-window"]]
      (is (= {:graph-identifier "North & South"
              :page-name "Overview" :block-id "node-id"}
             (select-keys
              (deeplink/parse-url (str "blocklog://" host "/North%20%26%20South?page=Overview&block-id=node-id"))
              [:graph-identifier :page-name :block-id])))))
  (testing "invalid external input produces a link error"
    (doseq [url [nil "not a url" "https://example.com" "blocklog://graph/Atlas%"
                "blocklog://graph/%E0%A4%A"]]
      (is (= :deeplink/invalid-link-error (:i18n-key (deeplink/parse-url url))))))
  (testing "a missing graph has a specific error"
    (is (= :electron/link-open-failed-missing-graph
           (:i18n-key (deeplink/parse-url "blocklog://graph/")))))
  (testing "other protocol actions remain available"
    (is (= "x-callback-url"
           (.-host (:parsed-url (deeplink/parse-url "blocklog://x-callback-url/quickCapture")))))))

(deftest startup-deeplink-urls-test
  (let [first-url "blocklog://graph/First"
        last-url "blocklog://graph/Last"
        capture "blocklog://x-callback-url/quickCapture"
        window "blocklog://new-window/First"
        argv ["Logseq" "--flag" first-url last-url]]
    (doseq [[pending mac? expected]
            [[[] false [first-url]]
             [[] true []]
             [[last-url] true [last-url]]
             [[last-url] false [last-url]]
             [["blocklog://graph?page=Overview"] false ["blocklog://graph?page=Overview"]]
             [[capture capture window window last-url] false
              [first-url capture capture window window last-url]]]]
      (is (= expected (deeplink/startup-deeplink-urls pending argv mac?))))
    (is (empty? (deeplink/startup-deeplink-urls [] ["Logseq" "/path/to/file"] false)))))
