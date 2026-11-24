(ns logseq.publish.node.server
  "Self-hosted publish server: runs the publish worker routes on Node.js with
  SQLite (metadata) and the filesystem (page payloads and assets)."
  (:require ["http" :as http]
            ["path" :as node-path]
            ["stream" :refer [Readable]]
            ["stream/promises" :refer [pipeline]]
            [clojure.string :as string]
            [logseq.publish.meta-store :as meta-store]
            [logseq.publish.node.storage :as storage]
            [logseq.publish.routes :as routes]
            [promesa.core :as p]))

(defn- env-value [k]
  (let [v (aget (.-env js/process) k)]
    (when-not (string/blank? v) v)))

(defn- required-env [k]
  (or (env-value k)
      (throw (js/Error. (str k " is not set")))))

(defn- meta-do-namespace
  "Durable Object namespace stand-in. Every object name shares one SQLite
  database: the worker writes each page to its page object and to the index
  object with the same upserts and deletes, so one copy holds the same data."
  [sql]
  (let [self #js {:sql sql}]
    #js {:idFromName identity
         :get (fn [_id]
                #js {:fetch (fn [url init]
                              (meta-store/do-fetch self (js/Request. url init)))})}))

(defn- make-env [data-dir]
  #js {"PUBLISH_META_DO" (meta-do-namespace (storage/open-meta-sql data-dir))
       "PUBLISH_R2" (storage/make-bucket (node-path/join data-dir "objects"))
       "AUTH_ISSUER" (required-env "AUTH_ISSUER")
       "AUTH_CLIENT_ID" (required-env "AUTH_CLIENT_ID")
       "AUTH_JWKS_URL" (required-env "AUTH_JWKS_URL")})

(defn- node->request [^js req]
  (let [headers (js/Headers.)
        method (.-method req)
        _ (doseq [[k v] (js/Object.entries (.-headers req))]
            (if (array? v)
              (doseq [item v] (.append headers k item))
              (.set headers k v)))
        init #js {:method method :headers headers}]
    (when-not (#{"GET" "HEAD"} method)
      (aset init "body" req)
      (aset init "duplex" "half"))
    (js/Request. (str "http://" (or (.get headers "host") "localhost") (.-url req)) init)))

(defn- send-response! [^js res ^js response]
  (let [headers (js-obj)]
    (.forEach (.-headers response) (fn [v k] (aset headers k v)))
    (.writeHead res (.-status response) headers)
    (if-let [body (.-body response)]
      (pipeline (.fromWeb Readable body) res)
      (.end res))))

(defn main [& _args]
  (let [port (js/parseInt (or (env-value "PUBLISH_PORT") "8788") 10)
        env (make-env (or (env-value "PUBLISH_DATA_DIR") "data/publish"))
        ^js server (.createServer
                http
                (fn [^js req ^js res]
                  ;; p/then turns a synchronous throw in a handler into a rejection
                  (-> (p/then (p/resolved nil) #(routes/handle-fetch (node->request req) env))
                      (p/then #(send-response! res %))
                      (p/catch (fn [error]
                                 (js/console.error "publish: request failed" (.-method req) (.-url req) error)
                                 (if (.-headersSent res)
                                   (.destroy res)
                                   (do (.writeHead res 500 #js {"content-type" "application/json"})
                                       (.end res "{\"error\":\"internal\"}"))))))))]
    (.listen server port (fn [] (js/console.log (str "Logseq publish listening on port " port))))))
