require "spec"
require "tui"
require "../../src/pkgx/widgets/work_list_view"

private class StubTableSource < TUI::TableDataSource
  def initialize(@count : Int32 = 20)
  end

  def columns : Array(TUI::TableColumn)
    [TUI::TableColumn.new("Name", 4, 10, expand: true)]
  end

  def size : Int32
    @count
  end

  def row(index : Int32) : TUI::TableRow
    TUI::TableRow.new(cells: [TUI::Cell.new("item-#{index}")])
  end

  def title(filter : String, sort_key : Symbol) : String
    "Stub"
  end

  def sort_keys : Array(Symbol)
    [:name]
  end

  def reload(filter : String, sort : Symbol) : Nil
  end
end

private def scroll(visible = 15) : TUI::ScrollControl
  TUI::ScrollControl.new(TUI::Scroller.new, visible)
end

describe Pkgx::WorkListView do
  describe "#status_hint" do
    it "appends app_hint when not filtering" do
      view = Pkgx::WorkListView.new(StubTableSource.new)
      view.reload
      view.app_hint = " x:remove  X:clear all"

      view.status_hint.should contain("x:remove")
      view.status_hint.should contain("X:clear all")
    end

    it "ignores app_hint while filtering" do
      view = Pkgx::WorkListView.new(StubTableSource.new)
      view.reload
      view.app_hint = " x:remove  X:clear all"

      view.handle_key(TUI::KeyEvent.new(TUI::Key::Char, '/'), scroll)

      view.status_hint.should contain("Type to filter")
      view.status_hint.should_not contain("x:remove")
    end
  end
end
