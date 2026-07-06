require "tui"
require "../work_list"
require "../format"

module Pkgx
  class WorkListSource < TUI::TableDataSource
    def initialize(@work_list : Pkgx::WorkList)
    end

    def columns : Array(TUI::TableColumn)
      [
        TUI::TableColumn.new("Action", 3, 10),
        TUI::TableColumn.new("Name", 8, 24, expand: true),
        TUI::TableColumn.new("Size", 6, 10, align: TUI::Align::Right),
      ]
    end

    def size : Int32
      @work_list.size + (@work_list.empty? ? 0 : 1)
    end

    def row(index : Int32) : TUI::TableRow
      if index == @work_list.size
        return TUI::TableRow.new(cells: [
          TUI::Cell.new(""),
          TUI::Cell.new("Net", style: TUI::Style.new(bold: true)),
          TUI::Cell.new(balance_text, style: balance_style),
        ])
      end

      entry = @work_list[index]
      return TUI::TableRow.new unless entry

      status = @work_list.status_for(entry.name)
      action_cell = action_cell_for(entry.action, status)
      name_style = case status
                   when :failed then TUI::Style.new(fg: TUI.color(:red))
                   when :done   then TUI::Style.new(dim: true)
                   else              TUI::Style.new
                   end
      TUI::TableRow.new(cells: [action_cell, TUI::Cell.new(entry.name, style: name_style), TUI::Cell.new(Pkgx::Format.bytes(entry.size))])
    end

    def title(filter : String, sort_key : Symbol) : String
      "Work List (#{@work_list.size})"
    end

    # A staged-changes list has no meaningful sort/filter — one fixed
    # "queued order" key, matching ListView's existing keys.size > 1
    # guard that already disables `s`-cycling when there's only one.
    def sort_keys : Array(Symbol)
      [:queued]
    end

    # WorkList is mutated directly by App (stage/unstage/remove_at/clear),
    # never by search/filter text, so there's nothing to reload here.
    def reload(filter : String, sort : Symbol) : Nil
    end

    private def action_cell_for(action : Pkgx::WorkList::Action, status : Symbol?) : TUI::Cell
      install = action.install?
      case status
      when :fetching
        TUI::Cell.new("… fetch", style: TUI::Style.new(fg: TUI.color(:yellow)))
      when :installing
        TUI::Cell.new("↻ install", style: TUI::Style.new(fg: TUI.color(:yellow)))
      when :removing
        TUI::Cell.new("↻ remove", style: TUI::Style.new(fg: TUI.color(:yellow)))
      when :done
        TUI::Cell.new(install ? "✓ done" : "✓ gone", style: TUI::Style.new(dim: true))
      when :failed
        TUI::Cell.new("✗ failed", style: TUI::Style.new(fg: TUI.color(:red)))
      else
        install ? TUI::Cell.new("+ install", style: TUI::Style.new(fg: TUI.color(:green))) : TUI::Cell.new("- remove", style: TUI::Style.new(fg: TUI.color(:red)))
      end
    end

    private def balance_text : String
      delta = @work_list.net_size_change
      sign = delta > 0 ? "+" : (delta < 0 ? "-" : "")
      "#{sign}#{Pkgx::Format.bytes(delta.abs)}"
    end

    private def balance_style : TUI::Style
      delta = @work_list.net_size_change
      delta > 0 ? TUI::Style.new(fg: TUI.color(:red)) : (delta < 0 ? TUI::Style.new(fg: TUI.color(:green)) : TUI::Style.new(dim: true))
    end
  end
end
