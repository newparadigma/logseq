(ns frontend.components.onboarding
  (:require [frontend.context.i18n :refer [t]]
            [frontend.state :as state]
            [frontend.ui :as ui]))

(defn help
  []
  [:div.help.cp__sidebar-help-docs
   (let [list
         [{:title (t :help/usage-title)
           :children [[[:a
                        {:on-click (fn [] (state/sidebar-add-block! (state/get-current-repo) "shortcut-settings" :shortcut-settings))}
                        [:div.flex-row.inline-flex.items-center
                         [:span.mr-1 (t :help.shortcuts/label)]
                         (ui/icon "command" {:style {:font-size 20}})]]]]}

          {:title (t :help/development-title)
           :children [[(t :help/bug) "https://github.com/newparadigma/logseq/issues/new"]]}]]

     (map (fn [{:keys [title children]}]
            ^{:key title}
            [:<>
             [:p.mt-4.mb-1 [:b title]]
             [:ul
              (map-indexed
               (fn [idx [title href]]
                 [:li {:key idx}
                  (if href
                    [:a {:href href :target "_blank"} title]
                    title)])
               children)]])
          list))])
