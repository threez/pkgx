require "spec"
require "tui"
require "../../src/pkgx/work_list"
require "../../src/pkgx/sources/work_list_source"

describe Pkgx::WorkListSource do
  describe "#size / #row / #title" do
    it "reflects an empty work list" do
      work_list = Pkgx::WorkList.new
      source = Pkgx::WorkListSource.new(work_list)

      source.size.should eq(0)
      source.title("", :queued).should eq("Work List (0)")
    end

    it "renders an install entry with a green '+ install' action cell, plus a trailing balance row" do
      work_list = Pkgx::WorkList.new
      work_list.stage("vim", Pkgx::WorkList::Action::Install, "9.1", "editors/vim", 5_000_000_i64)
      source = Pkgx::WorkListSource.new(work_list)

      source.size.should eq(2)
      row = source.row(0)
      row.cells[0].text.should eq("+ install")
      row.cells[0].style.should eq(TUI::Style.new(fg: TUI.color(:green)))
      row.cells[1].text.should eq("vim")
      row.cells[2].text.should eq(Pkgx::Format.bytes(5_000_000_i64))
      source.title("", :queued).should eq("Work List (1)")
    end

    it "renders a remove entry with a red '- remove' action cell" do
      work_list = Pkgx::WorkList.new
      work_list.stage("htop", Pkgx::WorkList::Action::Remove)
      source = Pkgx::WorkListSource.new(work_list)

      row = source.row(0)
      row.cells[0].text.should eq("- remove")
      row.cells[0].style.should eq(TUI::Style.new(fg: TUI.color(:red)))
      row.cells[1].text.should eq("htop")
    end
  end

  describe "balance row" do
    it "is absent when the work list is empty" do
      source = Pkgx::WorkListSource.new(Pkgx::WorkList.new)
      source.size.should eq(0)
    end

    it "shows a red positive net when installs outweigh removals" do
      work_list = Pkgx::WorkList.new
      work_list.stage("vim", Pkgx::WorkList::Action::Install, size: 10_000_000_i64)
      work_list.stage("htop", Pkgx::WorkList::Action::Remove, size: 4_000_000_i64)
      source = Pkgx::WorkListSource.new(work_list)

      balance_row = source.row(source.size - 1)
      balance_row.cells[1].text.should eq("Net")
      balance_row.cells[1].style.should eq(TUI::Style.new(bold: true))
      balance_row.cells[2].text.should eq("+#{Pkgx::Format.bytes(6_000_000_i64)}")
      balance_row.cells[2].style.should eq(TUI::Style.new(fg: TUI.color(:red)))
    end

    it "shows a green negative net when removals outweigh installs" do
      work_list = Pkgx::WorkList.new
      work_list.stage("vim", Pkgx::WorkList::Action::Install, size: 1_000_000_i64)
      work_list.stage("htop", Pkgx::WorkList::Action::Remove, size: 4_000_000_i64)
      source = Pkgx::WorkListSource.new(work_list)

      balance_row = source.row(source.size - 1)
      balance_row.cells[2].text.should eq("-#{Pkgx::Format.bytes(3_000_000_i64)}")
      balance_row.cells[2].style.should eq(TUI::Style.new(fg: TUI.color(:green)))
    end
  end

  describe "#columns" do
    it "returns the Action, Name, and Size columns" do
      source = Pkgx::WorkListSource.new(Pkgx::WorkList.new)
      headers = source.columns.map(&.header)
      headers.should eq(["Action", "Name", "Size"])
    end

    it "right-aligns the Size column" do
      source = Pkgx::WorkListSource.new(Pkgx::WorkList.new)
      size_col = source.columns.find! { |col| col.header == "Size" }
      size_col.align.should eq(TUI::Align::Right)
    end
  end

  describe "#sort_keys" do
    it "has a single fixed sort key" do
      source = Pkgx::WorkListSource.new(Pkgx::WorkList.new)
      source.sort_keys.should eq([:queued])
    end
  end
end
