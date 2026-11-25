(ns frontend.handler.common.plugin
  "Common plugin related fns for handlers and api"
  (:require [cljs-bean.core :as bean]
            [electron.ipc :as ipc]
            [frontend.state :as state]
            [frontend.util :as util]))

(defn installed?
  "For the given plugin id, returns boolean indicating if it is installed"
  [id]
  (contains? (:plugin/installed-plugins (state/get-state)) (keyword id)))

(defn emit-lsp-updates!
  [payload]
  (js/console.log "debug:lsp-updates:" payload)
  (js/window.apis.emit (name :lsp-updates) (bean/->js payload)))

(defn install-marketplace-plugin!
  "Installs plugin given plugin map with id"
  [{:keys [id] :as manifest}]
  (when-not (and (:plugin/installing (state/get-state))
                 (installed? id))
    (when-not (util/electron?)
      (throw (ex-info "Installing plugins needs the desktop app" {:id id})))
    (state/set-state! :plugin/installing manifest)
    (ipc/ipc :installMarketPlugin manifest)))

(defn unregister-plugin
  "Unregister and uninstall plugin given plugin id"
  [id]
  (js/LSPluginCore.unregister id))
