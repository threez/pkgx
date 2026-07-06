require "spec"
require "../src/pkgx/work_list"

describe Pkgx::WorkList do
  describe "#stage" do
    it "adds a new entry" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Install, "9.1", "editors/vim")

      list.size.should eq(1)
      list.staged?("vim").should be_true
      list.action_for("vim").should eq(Pkgx::WorkList::Action::Install)
    end

    it "replaces rather than duplicates when the same name is staged again with a different action" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Install)
      list.stage("vim", Pkgx::WorkList::Action::Remove)

      list.size.should eq(1)
      list.action_for("vim").should eq(Pkgx::WorkList::Action::Remove)
    end
  end

  describe "#unstage" do
    it "removes the entry for the given name" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Install)
      list.unstage("vim")

      list.staged?("vim").should be_false
      list.empty?.should be_true
    end

    it "is a no-op for a name that isn't staged" do
      list = Pkgx::WorkList.new
      list.unstage("nope")
      list.empty?.should be_true
    end
  end

  describe "#remove_at" do
    it "removes the entry at the given index" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Install)
      list.stage("htop", Pkgx::WorkList::Action::Remove)

      list.remove_at(0)

      list.size.should eq(1)
      list.staged?("htop").should be_true
      list.staged?("vim").should be_false
    end

    it "bounds-checks without raising" do
      list = Pkgx::WorkList.new
      list.remove_at(0)
      list.remove_at(-1)
      list.empty?.should be_true
    end
  end

  describe "#install_names / #remove_names" do
    it "partitions a mixed work list" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Install)
      list.stage("firefox", Pkgx::WorkList::Action::Install)
      list.stage("htop", Pkgx::WorkList::Action::Remove)

      list.install_names.sort.should eq(["firefox", "vim"])
      list.remove_names.should eq(["htop"])
    end
  end

  describe "#clear / #empty?" do
    it "empties the list" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Install)
      list.clear

      list.empty?.should be_true
      list.size.should eq(0)
    end
  end

  describe "#net_size_change" do
    it "sums installs as positive" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Install, size: 1_000_i64)
      list.stage("firefox", Pkgx::WorkList::Action::Install, size: 2_000_i64)

      list.net_size_change.should eq(3_000_i64)
    end

    it "sums removals as negative" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Remove, size: 1_000_i64)
      list.stage("firefox", Pkgx::WorkList::Action::Remove, size: 2_000_i64)

      list.net_size_change.should eq(-3_000_i64)
    end

    it "nets installs against removals" do
      list = Pkgx::WorkList.new
      list.stage("vim", Pkgx::WorkList::Action::Install, size: 10_000_000_i64)
      list.stage("htop", Pkgx::WorkList::Action::Remove, size: 4_000_000_i64)

      list.net_size_change.should eq(6_000_000_i64)
    end

    it "is zero for an empty list" do
      list = Pkgx::WorkList.new
      list.net_size_change.should eq(0_i64)
    end
  end
end
