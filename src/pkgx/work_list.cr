module Pkgx
  class WorkList
    enum Action
      Install
      Remove
    end

    record Entry, name : String, action : Action, version : String = "", origin : String = "", size : Int64 = 0_i64

    def initialize
      @entries = [] of Entry
      @status = {} of String => Symbol
    end

    def empty? : Bool
      @entries.empty?
    end

    def size : Int32
      @entries.size
    end

    def to_a : Array(Entry)
      @entries.dup
    end

    def [](index : Int32) : Entry?
      @entries[index]?
    end

    # Adds or replaces the entry for `name` — a package can only be
    # queued once; re-staging with a different action overwrites the
    # prior one rather than duplicating.
    def stage(name : String, action : Action, version : String = "", origin : String = "", size : Int64 = 0_i64) : Nil
      @entries.reject! { |entry| entry.name == name }
      @entries << Entry.new(name, action, version, origin, size)
    end

    def unstage(name : String) : Nil
      @entries.reject! { |entry| entry.name == name }
    end

    def staged?(name : String) : Bool
      @entries.any? { |entry| entry.name == name }
    end

    def action_for(name : String) : Action?
      @entries.find { |entry| entry.name == name }.try(&.action)
    end

    def remove_at(index : Int32) : Nil
      @entries.delete_at(index) if index >= 0 && index < @entries.size
    end

    def clear : Nil
      @entries.clear
      @status.clear
    end

    # Transient per-package apply status (:pending, :fetching, :installing,
    # :removing, :done, :failed), keyed by name. Populated by Browser#apply
    # via the libpkg event callback while an apply runs; read live by
    # WorkListSource#row. Not part of the staged model.
    def status_for(name : String) : Symbol?
      @status[name]?
    end

    def set_status(name : String, state : Symbol) : Nil
      @status[name] = state
    end

    def install_names : Array(String)
      @entries.select(&.action.install?).map(&.name)
    end

    def remove_names : Array(String)
      @entries.select(&.action.remove?).map(&.name)
    end

    # Net disk-space change if this work list were applied right now:
    # positive means installs outweigh removals (net cost), negative
    # means removals outweigh installs (net space freed).
    def net_size_change : Int64
      @entries.sum { |entry| entry.action.install? ? entry.size : -entry.size }
    end
  end
end
