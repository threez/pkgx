# Architecture

`Pkgx::App` (`src/pkgx/app.cr`) is the composition root: it builds the
`Browser`, the data sources, the widgets, and wires everything through a
`TUI::Runtime`. Read `App#handle_key` to see the full keybinding dispatch
in one place — app-specific keys are intercepted there before falling
through to whatever widget is current, so `tui.cr` itself stays unaware
of any pkgx-specific concept (mode, work list, staging).

- **`Browser`** (`src/pkgx/browser.cr`) — the only place that talks to
  `FreeBSD::Pkg`. Read paths (`search`, `load`, `installed_names`,
  `reverse_deps`, `shlib_users`) each open their own `Database` handle per
  call and swallow `FreeBSD::Pkg::Error` into an empty result, since a
  transient pkg-db error shouldn't crash the browser. `apply(work_list)`
  is the one write path: opens `Database::Type::MaybeRemote`, takes an
  advisory lock, and runs removals before installs (each its own
  `FreeBSD::Pkg::Jobs` transaction — solve, then apply), raising
  `FreeBSD::Pkg::Error` on failure or locked packages rather than
  swallowing it, since a failed *write* needs to surface to the user.

- **`WorkList`** (`src/pkgx/work_list.cr`) — a plain, TUI-agnostic staging
  list of `{name, action, version, origin}` entries, keyed by package
  name (`stage` replaces rather than duplicates; a package can only be
  queued once at a time). This is what `App` mutates on `a`/`x`/`X`/`A`
  and what `Browser#apply` consumes.

- **Sources** (`src/pkgx/sources/`) adapt domain data to `tui.cr`'s
  `TableDataSource`/`DetailDataSource` contracts:
  - `PackageListSource` — backs the main table in both modes. Tracks
    `@installed : Set(String)` (populated from `Browser#installed_names`,
    Available mode only) for the `[I]`/`[ ]` indicator column, and
    consults the shared `WorkList` to render a leading `›` marker on any
    staged row, colored green (staged for install) or red (staged for
    removal) to match the work-list pane's own color convention.
  - `PackageDetailSource` — backs the detail view; `:rdeps` and
    `:shlib_users` are lazy expansions (only queried when toggled open).
  - `WorkListSource` — backs the work-list pane; two columns
    (`Action`, `Name`), no real sort/filter (a staged-changes list is
    short-lived and always shown in queued order).

- **Widgets** (`src/pkgx/widgets/`) are thin `TUI::TableView` subclasses
  that only override `status_hint`, since `tui.cr`'s generic hint text
  doesn't know about pkgx's actual keybindings (`PackageListView`,
  `WorkListView`).

## The work-list panel: Window ↔ SplitWindow swap

`TUI::SplitWindow` has no built-in way to hide one of its two panes — both
always render. Since "nothing extra shown when the work list is empty" is
a hard requirement, `App` instead holds **two** pre-built outer widgets
wrapping the *same* `PackageListView` instance:

- `@pkg_list_plain` — a plain `TUI::Window` (today's single-pane look).
- `@pkg_list_split` — a `TUI::SplitWindow` with the table as the left pane
  and the work-list view as the right pane.

`sync_work_list_view` (called after every stage/unstage/clear/apply)
swaps which of the two sits at the bottom of the `NavStack` via
`TUI::Runtime#replace_base`, based on `@work_list.empty?`. It also calls
`@pkg_list_split.focus_left` before swapping the split back in, so
re-showing it always starts with the table focused rather than carrying
over whatever pane was last active.

Errors from `Browser#apply` (locked packages, permission denied, etc.)
are shown via `TUI::Popup`, pushed directly onto the `NavStack` (bypassing
`Runtime#push`'s forced full-screen resize) and dismissed by any key.
