require "tui"

module Pkgx
  class WorkListView < TUI::TableView
    property app_hint : String = ""

    def status_hint : String
      @filter_active ? super : super + app_hint
    end
  end
end
