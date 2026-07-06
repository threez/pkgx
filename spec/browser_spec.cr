require "spec"
require "../src/pkgx/browser"
require "../src/pkgx/work_list"

describe Pkgx::Browser do
  describe "#apply" do
    it "returns immediately without touching the pkg database when the work list is empty" do
      browser = Pkgx::Browser.new
      work_list = Pkgx::WorkList.new

      # An empty work list must short-circuit before ever calling
      # FreeBSD::Pkg::Database.open — the only branch of #apply that's
      # safely exercisable without a real, writable, rootful pkg db.
      # Everything past this point (Database.open(:maybe_remote),
      # Jobs.solve/#apply) has no mocking seam in freebsd.cr and is
      # manual/live-verification only.
      browser.apply(work_list)
    end
  end
end
