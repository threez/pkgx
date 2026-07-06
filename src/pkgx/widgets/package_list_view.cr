require "tui"

module Pkgx
  class PackageListView < TUI::TableView
    property app_hint : String = ""

    def status_hint : String
      @filter_active ? super : super + app_hint
    end
  end
end
