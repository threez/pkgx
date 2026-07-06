require "tui"
require "./browser"
require "./format"
require "./work_list"
require "./sources/package_list_source"
require "./sources/package_detail_source"
require "./sources/work_list_source"
require "./widgets/work_list_view"
require "./widgets/package_list_view"

module Pkgx
  class App
    @list_menu : TUI::KeyMenu

    def self.run : Nil
      FreeBSD::Pkg.init do
        new.run
      end
    end

    def initialize
      @browser = Browser.new
      @screen = TUI::Screen.new

      rows = @screen.rows
      cols = @screen.cols

      @work_list = Pkgx::WorkList.new
      @list_source = Pkgx::PackageListSource.new(@browser, @work_list)
      @detail_source = Pkgx::PackageDetailSource.new(@browser)
      @work_list_source = Pkgx::WorkListSource.new(@work_list)

      @pkg_list_content = Pkgx::PackageListView.new(@list_source)
      @pkg_detail_content = TUI::DetailView.new(@detail_source)
      @work_list_content = Pkgx::WorkListView.new(@work_list_source)

      # Both wrap the SAME @pkg_list_content instance — only one of these
      # is ever the live nav-stack base at a time (see sync_work_list_view).
      @pkg_list_plain = TUI::Window.new(1, 1, cols, rows - 1, @pkg_list_content)
      @pkg_list_split = TUI::SplitWindow.new(1, 1, cols, rows - 1,
        @pkg_list_content, @work_list_content, left_width: (cols * 2 // 3))
      @pkg_detail = TUI::Window.new(1, 1, cols, rows - 1, @pkg_detail_content)

      @nav = TUI::NavStack(TUI::Widget).new(@pkg_list_plain.as(TUI::Widget))
      @runtime = TUI::Runtime.new(@screen, @nav, ->(ev : TUI::KeyEvent) { handle_key(ev) })
      @list_menu = build_list_menu

      wire_list
      @pkg_list_content.focused = true
      @pkg_list_content.reload
      refresh_list_hint
    end

    def run : Nil
      @runtime.run
    end

    private def wire_list : Nil
      @pkg_list_content.on_activate = ->(index : Int32) {
        pkg = @list_source.package_at(index)
        open_detail(pkg.name) if pkg
        nil
      }
    end

    private def open_detail(pkg_name : String) : Nil
      @pkg_list_content.focused = false
      @pkg_detail_content.load(pkg_name)
      @pkg_detail.reset_scroll
      @runtime.push(@pkg_detail.as(TUI::Widget))
    end

    private def build_list_menu : TUI::KeyMenu
      menu = TUI::KeyMenu.new
      menu.bind('q', "q:quit") { exit(0) }
      menu.bind('m', "m:mode") { toggle_mode }
      menu.bind(' ', "Space:stage", when: -> { table_focused? }) { stage_selected }
      menu.bind('x', "x:remove", when: -> { !table_focused? }) { unstage_selected }
      menu.bind(' ', "Space:unstage", when: -> { !table_focused? }) { unstage_selected }
      menu.bind('X', "X:clear all", when: -> { !table_focused? }) { clear_work_list }
      menu.bind('A', "A:apply") { apply_work_list }
      menu.bind(TUI::Key::Enter, "Enter:detail", when: -> { table_focused? }) do
        if idx = @pkg_list_content.selected_index
          pkg = @list_source.package_at(idx)
          open_detail(pkg.name) if pkg
        end
      end
      menu
    end

    private def table_focused? : Bool
      current = @nav.current
      current == @pkg_list_plain || @pkg_list_content.focused?
    end

    private def handle_key(ev : TUI::KeyEvent) : Nil
      current = @nav.current

      if current.is_a?(TUI::Popup)
        current.handle_key(ev)
        @nav.pop
        @pkg_list_content.focused = true
        return
      end

      if ev.key == TUI::Key::Esc
        @runtime.handle_esc(current.handle_key(ev)) { @pkg_list_content.focused = true }
        refresh_list_hint
        return
      end

      if current == @pkg_list_plain || current == @pkg_list_split
        consumed = !@pkg_list_content.filter_active? && @list_menu.dispatch(ev)
        current.handle_key(ev) unless consumed
        refresh_list_hint
        return
      end

      current.handle_key(ev)
    end

    private def refresh_list_hint : Nil
      hint = @list_menu.hint
      @pkg_list_content.app_hint = hint
      @work_list_content.app_hint = hint
    end

    private def toggle_mode : Nil
      @list_source.toggle_mode
      @pkg_list_content.reload
    end

    private def stage_selected : Nil
      idx = @pkg_list_content.selected_index
      return unless idx
      pkg = @list_source.package_at(idx)
      return unless pkg

      if @work_list.staged?(pkg.name)
        @work_list.unstage(pkg.name)
      else
        installed = @list_source.mode.installed? || @list_source.installed?(pkg.name)
        action = installed ? Pkgx::WorkList::Action::Remove : Pkgx::WorkList::Action::Install
        @work_list.stage(pkg.name, action, pkg.version, pkg.origin, pkg.installed_size)
      end
      sync_work_list_view
    end

    private def unstage_selected : Nil
      idx = @work_list_content.selected_index
      return unless idx
      @work_list.remove_at(idx)
      @work_list_content.reload
      sync_work_list_view
    end

    private def clear_work_list : Nil
      @work_list.clear
      @work_list_content.reload
      sync_work_list_view
    end

    private def apply_work_list : Nil
      return if @work_list.empty?

      @work_list.to_a.each { |entry| @work_list.set_status(entry.name, :pending) }
      @runtime.render_now

      begin
        @browser.apply(@work_list, repaint: -> { @runtime.render_now })
        @work_list.clear
      rescue ex : FreeBSD::Pkg::Error
        mark_unfinished_failed
        @runtime.render_now
        popup = TUI::Popup.centered(@screen, "Error", ex.message || "apply failed")
        @nav.push(popup.as(TUI::Widget))
      ensure
        @pkg_list_content.reload
        @work_list_content.reload
        sync_work_list_view
      end
    end

    # Anything not already :done when apply raised is marked :failed (rather
    # than left :pending) so the sidebar shows where the apply stopped
    # instead of implying those packages are still queued.
    private def mark_unfinished_failed : Nil
      @work_list.to_a.each do |entry|
        status = @work_list.status_for(entry.name)
        @work_list.set_status(entry.name, :failed) unless status == :done
      end
    end

    # Swaps which widget (plain single-pane table, or table+work-list
    # split) sits at the bottom of the nav stack, based on whether the
    # work list is empty — SplitWindow itself always renders both panes,
    # so "nothing shown when empty" has to be handled by not using it.
    private def sync_work_list_view : Nil
      current = @nav.current
      return unless current == @pkg_list_plain || current == @pkg_list_split
      target = @work_list.empty? ? @pkg_list_plain : @pkg_list_split
      return if current == target
      @pkg_list_split.focus_left
      @runtime.replace_base(target.as(TUI::Widget))
      @pkg_list_content.focused = true
      @work_list_content.focused = false
    end
  end
end
