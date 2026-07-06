require "freebsd/pkg"
require "./work_list"

module Pkgx
  class Browser
    enum Mode
      Installed
      Available
    end

    property mode : Mode = Mode::Installed

    def search(term : String,
               match : FreeBSD::Pkg::MatchType | Symbol = :regex,
               flags : FreeBSD::Pkg::LoadFlags | Symbol | Enumerable(Symbol | FreeBSD::Pkg::LoadFlags) = FreeBSD::Pkg::LoadFlags::None) : Array(FreeBSD::Pkg::Package)
      result = [] of FreeBSD::Pkg::Package
      case @mode
      when Mode::Installed
        FreeBSD::Pkg::Database.open(:local) do |db|
          result = term.empty? ? db.query(flags: flags) : db.query(term, match: match, flags: flags)
        end
      when Mode::Available
        FreeBSD::Pkg::Database.open(:remote) do |db|
          result = term.empty? ? db.repo_query("*", match: :glob, flags: flags) : db.repo_query(term, match: match, flags: flags)
        end
      end
      result
    rescue ex : FreeBSD::Pkg::Error
      [] of FreeBSD::Pkg::Package
    end

    def load(name : String) : FreeBSD::Pkg::Package?
      flags = @mode.installed? ? [:categories, :licenses, :deps, :rdeps, :shlibs_required] : [:categories, :licenses, :deps, :shlibs_required]
      search(name, match: :exact, flags: flags).first?
    rescue ex : FreeBSD::Pkg::Error
      nil
    end

    def installed_names : Set(String)
      result = Set(String).new
      FreeBSD::Pkg::Database.open(:local) do |db|
        db.each { |pkg| result << pkg.name }
      end
      result
    rescue FreeBSD::Pkg::Error
      Set(String).new
    end

    def reverse_deps(name : String) : Array(String)
      result = [] of String
      FreeBSD::Pkg::Database.open(:local) do |db|
        pkgs = db.query(name, match: :exact, flags: :rdeps)
        pkgs.first?.try do |pkg|
          pkg.each_reverse_dependency { |dep| result << "#{dep.name}-#{dep.version}" }
        end
      end
      result
    rescue FreeBSD::Pkg::Error
      [] of String
    end

    def shlib_users(shlib : String) : Array(String)
      result = [] of String
      FreeBSD::Pkg::Database.open(:local) do |db|
        db.requiring_shlib(shlib).each { |pkg| result << "#{pkg.name}-#{pkg.version}" }
      end
      result
    rescue FreeBSD::Pkg::Error
      [] of String
    end

    # Executes a staged WorkList for real: removals first (frees up
    # conflicts before installs run), then installs, each as its own
    # Jobs transaction since the underlying API is one Kind per handle.
    # Requires write access to the pkg db (root) — raises
    # FreeBSD::Pkg::Error on failure or if locked packages block the job.
    #
    # *repaint*, if given, is called after every per-package status change
    # (via the libpkg event callback) so a caller holding the TUI runtime can
    # force a redraw mid-apply instead of the screen sitting frozen until this
    # whole call returns.
    def apply(work_list : Pkgx::WorkList, repaint : Proc(Nil) = -> { }) : Nil
      install_names = work_list.install_names
      remove_names = work_list.remove_names
      return if install_names.empty? && remove_names.empty?

      register_progress(work_list, repaint)
      begin
        FreeBSD::Pkg::Database.open(:maybe_remote) do |db|
          db.with_advisory_lock do
            unless remove_names.empty?
              FreeBSD::Pkg::Jobs.remove(db, remove_names) do |jobs|
                jobs.solve
                raise FreeBSD::Pkg::Error.new("locked packages block removal") if jobs.has_locked_packages?
                jobs.apply
              end
            end
            unless install_names.empty?
              FreeBSD::Pkg::Jobs.install(db, install_names) do |jobs|
                jobs.solve
                raise FreeBSD::Pkg::Error.new("locked packages block install") if jobs.has_locked_packages?
                jobs.apply
              end
            end
          end
        end
      ensure
        reset_progress
      end
    end

    # Registers libpkg's process-global event callback so per-package
    # install/remove phase changes are reflected on *work_list* and repainted
    # live. Copies every field out of the event immediately — an `Event` (and
    # any `Package` it hands back) is only valid for the callback's own stack
    # frame and must never be retained past it.
    private def register_progress(work_list : Pkgx::WorkList, repaint : Proc(Nil)) : Nil
      FreeBSD::Pkg::EventCallbacks.register do |event|
        case event.kind
        when .install_begin?
          if name = event.package.try(&.name)
            work_list.set_status(name, :installing)
            repaint.call
          end
        when .install_finished?
          if name = event.package.try(&.name)
            work_list.set_status(name, :done)
            repaint.call
          end
        when .deinstall_begin?
          if name = event.package.try(&.name)
            work_list.set_status(name, :removing)
            repaint.call
          end
        when .deinstall_finished?
          if name = event.package.try(&.name)
            work_list.set_status(name, :done)
            repaint.call
          end
        end
      end
    end

    # There is no libpkg call to unregister the (process-global, one-at-a-time)
    # event callback — re-registering a no-op is the documented way to clear
    # it, preventing a stale closure from firing during a later, unrelated
    # libpkg call.
    private def reset_progress : Nil
      FreeBSD::Pkg::EventCallbacks.register { |_event| }
    end
  end
end
