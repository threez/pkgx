require "../browser"
require "../format"
require "../work_list"

module Pkgx
  class PackageListSource < TUI::TableDataSource
    def mode : Pkgx::Browser::Mode
      @browser.mode
    end

    def initialize(@browser : Pkgx::Browser, @work_list : Pkgx::WorkList)
      @packages = [] of FreeBSD::Pkg::Package
      @installed = Set(String).new
    end

    def columns : Array(TUI::TableColumn)
      cols = [] of TUI::TableColumn
      cols << TUI::TableColumn.new("", 1, 1)
      cols << TUI::TableColumn.new("I", 3, 3) if mode.available?
      cols << TUI::TableColumn.new("Name", 8, 26, expand: true)
      cols << TUI::TableColumn.new("Version", 8, 16)
      cols << TUI::TableColumn.new("Size", 6, 10, align: TUI::Align::Right)
      cols << TUI::TableColumn.new("Origin", 8, 30)
      cols
    end

    def size : Int32
      @packages.size
    end

    def row(index : Int32) : TUI::TableRow
      pkg = @packages[index]
      action = @work_list.action_for(pkg.name)
      queued = !action.nil?
      marker_style = case action
                     when .try(&.install?) then TUI::Style.new(fg: TUI.color(:green))
                     when .try(&.remove?)  then TUI::Style.new(fg: TUI.color(:red))
                     else                       TUI::Style.new
                     end
      cells = [] of TUI::Cell
      cells << TUI::Cell.new(queued ? "›" : " ", style: marker_style)
      if mode.available?
        installed = @installed.includes?(pkg.name)
        cells << TUI::Cell.new(installed ? "[I]" : "[ ]", style: installed ? TUI::Style.new(fg: TUI.color(:green)) : TUI::Style.new(dim: true))
      end
      cells << TUI::Cell.new(pkg.name, style: queued ? TUI::Style.new(dim: true) : TUI::Style.new)
      cells << TUI::Cell.new(pkg.version, style: queued ? TUI::Style.new(dim: true) : TUI::Style.new)
      cells << TUI::Cell.new(Pkgx::Format.bytes(pkg.installed_size), style: queued ? TUI::Style.new(dim: true) : TUI::Style.new)
      cells << TUI::Cell.new(pkg.origin, style: TUI::Style.new(dim: true))
      TUI::TableRow.new(cells: cells)
    end

    def title(filter : String, sort_key : Symbol) : String
      mode_label = mode.installed? ? "Installed" : "Available"
      sort_label = sort_key == :name ? "" : " ↕#{sort_key}"
      count = @packages.size
      filter.empty? ? "#{mode_label}#{sort_label} (#{count})" : "#{mode_label}#{sort_label} (#{count}) /#{filter}"
    end

    def sort_keys : Array(Symbol)
      [:name, :size, :origin]
    end

    def reload(filter : String, sort : Symbol) : Nil
      pkgs = @browser.search(filter)
      @packages = sort_packages(pkgs, sort)
      @installed = mode.available? ? @browser.installed_names : Set(String).new
    end

    def toggle_mode : Nil
      @browser.mode = @browser.mode.installed? ? Pkgx::Browser::Mode::Available : Pkgx::Browser::Mode::Installed
    end

    def package_at(index : Int32) : FreeBSD::Pkg::Package?
      @packages[index]?
    end

    def installed?(name : String) : Bool
      @installed.includes?(name)
    end

    private def sort_packages(pkgs : Array(FreeBSD::Pkg::Package), sort : Symbol) : Array(FreeBSD::Pkg::Package)
      case sort
      when :size   then pkgs.sort_by { |pkg| -pkg.installed_size }
      when :origin then pkgs.sort_by(&.origin)
      else              pkgs.sort_by(&.name)
      end
    end
  end
end
