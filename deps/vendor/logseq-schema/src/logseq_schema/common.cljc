(ns logseq-schema.common
  (:require [logseq.clj-fractional-indexing :as index]))

(defn- validate-order-key?
  [key]
  (index/validate-order-key key index/base-62-digits)
  true)

(def major-schema-version-string-schema
  [:and :string
   [:fn
    {:error/message "should be a major schema-version"}
    (fn [s] (some? (parse-long s)))]])

(def block-order
  [:and :string [:fn
                 {:error/message "should be a valid fractional index"}
                 validate-order-key?]])
