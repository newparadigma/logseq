(ns logseq.publish.render-test
  (:require [cljs.test :refer [deftest is testing]]
            [logseq.db :as ldb]
            [logseq.publish.render :as render]))

(deftest entity-properties-filters-explicitly-hidden-properties
  (testing "property is filtered when ctx marks it hidden"
    (let [entity {:user.property/secret "value"}
          ctx {:property-hidden-by-ident {:user.property/secret true}}
          result (render/entity-properties entity ctx {})]
      (is (nil? (get result :user.property/secret))))))

(deftest entity-properties-filters-built-in-hidden-properties
  (testing "built-in properties with :hide? true are filtered without property entity metadata"
    (let [entity {:logseq.property/created-from-property "some-value"}
          ctx {:property-hidden-by-ident {}}
          result (render/entity-properties entity ctx {})]
      (is (nil? (get result :logseq.property/created-from-property))))))

(deftest filter-tags-removes-built-in-tag-values
  (testing "built-in class keyword tags are removed"
    (let [result (render/filter-tags [:logseq.class/Tag :user.property/custom] {})]
      (is (= [:user.property/custom] result))))
  (testing "built-in class entities are removed"
    (let [entities {1 {:db/ident :logseq.class/Tag}
                    2 {:db/ident :user.property/custom}}
          result (render/filter-tags [1 2] entities)]
      (is (= [2] result)))))

(deftest block-content-nodes-use-auto-dir
  (let [node (render/block-content-nodes
              {:block/title "english then عربي"}
              {:uuid->title {} :graph-uuid "g"}
              1)]
    (is (= "auto" (get-in node [1 :dir])))))

(deftest block-content-from-ref-uses-auto-dir
  (let [node (render/block-content-from-ref
              {"source_block_content" "كلام عربي then english"}
              {:uuid->title {} :graph-uuid "g"})]
    (is (= "auto" (get-in node [1 :dir])))))

(deftest render-properties-use-auto-dir
  (let [props {:user.property/sample "english then عربي"}
        ctx {:property-title-by-ident {}
             :property-type-by-ident {}}
        rendered (render/render-properties props ctx {})
        entry (first (second rendered))
        dd-node (nth entry 2)]
    (is (= :dd.property-value (first dd-node)))
    (is (= "auto" (get-in dd-node [1 :dir])))))

(deftest block-content-nodes-embeds-youtube-shorts-player
  (let [node (render/block-content-nodes
              {:block/title "{{video https://www.youtube.com/shorts/xu9p5ynlhZk}}"}
              {:uuid->title {} :graph-uuid "g"}
              1)
        html (render/render-hiccup node)]
    (is (re-find #"https://www\.youtube\.com/embed/xu9p5ynlhZk" html))))

(deftest page-html-loads-nothing-from-other-hosts-and-hides-empty-authors
  (let [page-uuid #uuid "00000000-0000-0000-0000-000000000001"
        transit (ldb/write-transit-str
                 {:datoms [[1 :block/uuid page-uuid 1 true]
                           [1 :block/title "Local page" 1 true]]
                  :meta {:graph "graph-1"}})
        html (render/render-page-html transit (str page-uuid) nil nil)]
    (is (re-find #"Local page" html))
    (testing "a page without created-by data shows no author line"
      (is (not (re-find #"By:" html))))
    (testing "styles, scripts and the favicon come from this server"
      (is (nil? (re-find #"(?:src|href)=\"(?:https?:)?//" html))))))

(deftest not-found-page-uses-the-home-layout
  (let [html (render/render-404-html)]
    (is (re-find #"publish-home-card" html))
    (is (re-find #"<h1 class=\"publish-home-title\">404</h1>" html))))

(deftest block-content-nodes-render-one-anchor-per-link
  (doseq [[title label] [["A link: https://github.com/newparadigma/logseq" "https://github.com/newparadigma/logseq"]
                         ["A link: [fork](https://github.com/newparadigma/logseq)" "fork"]]]
    (let [html (render/render-hiccup
                (render/block-content-nodes {:block/title title} {:uuid->title {} :graph-uuid "g"} 1))]
      (is (= 1 (count (re-seq #"<a " html))) title)
      (is (re-find (re-pattern (str "<a href=\"https://github.com/newparadigma/logseq\">" label "</a>")) html) title))))
