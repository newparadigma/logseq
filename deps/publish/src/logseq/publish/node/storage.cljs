(ns logseq.publish.node.storage
  "Node stand-ins for the Cloudflare bindings of the publish worker:
  a SQLite database for the metadata Durable Object and a filesystem bucket for R2."
  (:require ["better-sqlite3" :as sqlite3]
            ["fs" :as fs]
            ["path" :as node-path]
            [promesa.core :as p]))

(defn- ensure-dir! [dir]
  (.mkdirSync fs dir #js {:recursive true}))

(defn- sql-arg
  "Cloudflare binds undefined as NULL; better-sqlite3 rejects it."
  [v]
  (if (undefined? v) nil v))

(defn open-meta-sql
  "Opens `data-dir`/meta.sqlite and returns an object with the `exec` API of
  Durable Object storage (`ctx.storage.sql`), as used by `logseq.publish.meta-store`."
  [data-dir]
  (ensure-dir! data-dir)
  (let [^js db (new sqlite3 (node-path/join data-dir "meta.sqlite"))]
    (.pragma db "journal_mode = WAL")
    #js {:exec (fn [sql-str & args]
                 (let [^js stmt (.prepare db sql-str)
                       args (to-array (map sql-arg args))
                       rows (if (.-reader stmt)
                              (.apply (.-all stmt) stmt args)
                              (do (.apply (.-run stmt) stmt args)
                                  #js []))]
                   #js {:toArray (fn [] rows)}))
         :close (fn [] (.close db))}))

(defn- key->path
  "Maps an object key to a file under `base-dir`. Keys are built from request
  data, so a key that leaves `base-dir` is rejected."
  [base-dir key]
  (let [file-path (node-path/resolve base-dir key)]
    (when-not (and (string? key)
                   (not (re-find #"\x00" key))
                   (.startsWith file-path (str base-dir (.-sep node-path)))
                   (not (.endsWith file-path ".meta.json")))
      (throw (ex-info "invalid object key" {:key key})))
    file-path))

(defn- read-meta [file-path]
  (p/let [content (.readFile (.-promises fs) (str file-path ".meta.json") "utf8")]
    (js/JSON.parse content)))

(defn- object [file-path ^js meta body]
  #js {:httpMetadata (or (.-httpMetadata meta) #js {})
       :customMetadata (or (.-customMetadata meta) #js {})
       :body body
       :arrayBuffer (fn []
                      (p/let [^js buf (or body (.readFile (.-promises fs) file-path))]
                        (.slice (.-buffer buf) (.-byteOffset buf) (+ (.-byteOffset buf) (.-byteLength buf)))))})

(defn- missing->nil [promise]
  (p/catch promise (fn [^js error]
                     (if (= "ENOENT" (.-code error))
                       nil
                       (throw error)))))

(defn make-bucket
  "Returns an object with the subset of the R2 bucket API the publish worker uses
  (`head`, `get`, `put`), storing each object and its metadata as files."
  [base-dir]
  (let [base-dir (node-path/resolve base-dir)]
    (ensure-dir! base-dir)
    #js {:head (fn [key]
                 (let [file-path (key->path base-dir key)]
                   (missing->nil
                    (p/let [_ (.stat (.-promises fs) file-path)
                            meta (read-meta file-path)]
                      (object file-path meta nil)))))
         :get (fn [key]
                (let [file-path (key->path base-dir key)]
                  (missing->nil
                   (p/let [body (.readFile (.-promises fs) file-path)
                           meta (read-meta file-path)]
                     (object file-path meta body)))))
         :put (fn [key body ^js opts]
                (let [file-path (key->path base-dir key)
                      tmp-path (str file-path ".upload-" (random-uuid))
                      meta #js {:httpMetadata (some-> opts .-httpMetadata)
                                :customMetadata (some-> opts .-customMetadata)}]
                  (ensure-dir! (node-path/dirname file-path))
                  ;; Metadata first: a file without its metadata never becomes visible.
                  (p/let [_ (.writeFile (.-promises fs) (str file-path ".meta.json") (js/JSON.stringify meta))
                          _ (.writeFile (.-promises fs) tmp-path (js/Uint8Array. body))
                          _ (.rename (.-promises fs) tmp-path file-path)]
                    nil)))}))
