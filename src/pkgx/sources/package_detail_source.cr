require "../browser"
require "../format"

module Pkgx
  class PackageDetailSource < TUI::DetailDataSource
    def initialize(@browser : Pkgx::Browser)
      @cached_pkg = nil.as(FreeBSD::Pkg::Package?)
    end

    def title(id : String) : String
      pkg = @cached_pkg
      pkg ? "#{pkg.name}-#{pkg.version}" : id
    end

    def lines(id : String, expansions : Set(Symbol)) : Array(TUI::DetailLine)
      pkg = @browser.load(id)
      @cached_pkg = pkg
      return [] of TUI::DetailLine unless pkg
      build_lines(pkg, expansions)
    end

    def toggles : Array(Symbol)
      [:rdeps, :shlib_users]
    end

    def toggle_label(sym : Symbol) : String
      case sym
      when :rdeps       then "dependents"
      when :shlib_users then "lib users"
      else                   sym.to_s
      end
    end

    private def build_lines(pkg : FreeBSD::Pkg::Package, expansions : Set(Symbol)) : Array(TUI::DetailLine)
      result = [] of TUI::DetailLine

      add_field(result, "Name", pkg.name)
      add_field(result, "Version", pkg.version)
      add_field(result, "Origin", pkg.origin)
      add_field(result, "Arch", pkg.arch)
      add_field(result, "ABI", pkg.abi)
      add_field(result, "Comment", pkg.comment)
      add_field(result, "Maintainer", pkg.maintainer)
      add_field(result, "Website", pkg.www)
      add_field(result, "Prefix", pkg.prefix)
      add_field(result, "Installed size", Pkgx::Format.bytes(pkg.installed_size))
      add_field(result, "Archive size", Pkgx::Format.bytes(pkg.archive_size))

      cats = pkg.categories
      add_field(result, "Categories", cats.join(", ")) unless cats.empty?

      lics = pkg.licenses
      add_field(result, "Licenses", lics.join(", ")) unless lics.empty?

      deps = [] of String
      pkg.each_dependency { |dep| deps << "#{dep.name}-#{dep.version}" }
      unless deps.empty?
        result << blank
        result << header("Dependencies")
        deps.each { |dep| result << body("  " + dep) }
      end

      shlibs = pkg.shlibs_required
      unless shlibs.empty?
        result << blank
        result << header("Libs required")
        shlibs.each { |shlib| result << body("  " + shlib) }

        if expansions.includes?(:shlib_users)
          shlibs.each do |shlib|
            users = @browser.shlib_users(shlib)
            next if users.empty?
            result << blank
            result << header("Users of #{shlib}")
            users.each { |user| result << body("  " + user) }
          end
        end
      end

      desc = pkg.description
      unless desc.empty?
        result << blank
        result << header("Description")
        desc.split('\n').each { |line| result << body(line) }
      end

      if expansions.includes?(:rdeps)
        rdeps = @browser.reverse_deps(pkg.name)
        result << blank
        if rdeps.empty?
          result << header("Dependents")
          result << TUI::DetailLine.new("", TUI::Cell.new("  (none)", style: TUI::Style.new(dim: true)))
        else
          result << header("Dependents (#{rdeps.size})")
          rdeps.each { |rdep| result << body("  " + rdep) }
        end
      end

      result
    end

    private def add_field(result : Array(TUI::DetailLine), label : String, value : String) : Nil
      result << TUI::DetailLine.new(label, value)
    end

    private def header(label : String) : TUI::DetailLine
      TUI::DetailLine.new(label, "")
    end

    private def body(value : String) : TUI::DetailLine
      TUI::DetailLine.new("", value)
    end

    private def blank : TUI::DetailLine
      TUI::DetailLine.new("", "")
    end
  end
end
