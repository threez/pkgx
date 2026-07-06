require "spec"
require "tui"
require "../../src/pkgx/browser"
require "../../src/pkgx/work_list"
require "../../src/pkgx/sources/package_list_source"

describe Pkgx::PackageListSource do
  describe "#columns" do
    it "right-aligns the Size column in Installed mode" do
      browser = Pkgx::Browser.new
      source = Pkgx::PackageListSource.new(browser, Pkgx::WorkList.new)

      size_col = source.columns.find! { |col| col.header == "Size" }
      size_col.align.should eq(TUI::Align::Right)
    end

    it "right-aligns the Size column in Available mode too" do
      browser = Pkgx::Browser.new
      browser.mode = Pkgx::Browser::Mode::Available
      source = Pkgx::PackageListSource.new(browser, Pkgx::WorkList.new)

      size_col = source.columns.find! { |col| col.header == "Size" }
      size_col.align.should eq(TUI::Align::Right)
    end
  end
end
