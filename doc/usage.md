# Usage

Browsing is read-only and needs no special privileges. Applying staged
installs/removals (`A`) writes to the package database and requires root.

## Package list (table pane)

| Key | Action |
| --- | --- |
| `↑`/`↓` | Move selection one row |
| `Page Up`/`Page Down` | Move selection one page |
| Mouse wheel | Scroll |
| Click a row | Select it |
| Double-click a row | Open its detail view (same as `Enter`) |
| `/` | Enter filter mode (see below) |
| `s` | Cycle sort key (name / size / origin) |
| `Enter` | Open the selected package's detail view |
| `m` | Toggle Installed / Available mode |
| `Space` | Stage the selected package for install (Installed mode) or removal (Available mode) |
| `Tab` | Switch focus to the work-list pane (only once something is staged — see below) |
| `A` | Apply the work list (installs/removes for real — needs root; works regardless of which pane is focused) |
| `q` | Quit |
| `Ctrl+C` / `Ctrl+D` | Quit immediately, from anywhere |

## Filter mode (after pressing `/`)

| Key | Action |
| --- | --- |
| Any character | Append to the filter text; the list re-filters live as you type |
| `Backspace` | Delete the last character |
| `↑`/`↓`, `Page Up`/`Page Down`, mouse wheel | Still scroll the (already-filtered) results |
| `Enter` | Commit the filter and open the selected row's detail view |
| `Esc` | Cancel filtering — clears the filter text and reloads the unfiltered list |

The filter text is matched as a regex against package name/version in both
Installed and Available mode.

## Work-list pane (staged changes)

Reach this pane with `Tab` once at least one package is staged — it only
appears alongside the table once the work list is non-empty.

| Key | Action |
| --- | --- |
| `↑`/`↓`, `Page Up`/`Page Down`, mouse wheel | Navigate/scroll the staged entries |
| `Tab` | Switch focus back to the package table |
| `Space` | Unstage the selected entry |
| `x` | Unstage the selected entry (same as `Space` here) |
| `X` | Clear the entire work list |
| `A` | Apply the work list (same as from the table pane) |

`s` (sort) has no effect here — the work list has only one order (the order
things were staged in).

## Detail view (`Enter` or double-click on a package)

| Key | Action |
| --- | --- |
| `↑`/`↓` | Scroll one line |
| `Page Up`/`Page Down` | Scroll one page |
| Mouse wheel | Scroll |
| `a` | Toggle the "dependents" (reverse dependencies) section |
| `b` | Toggle the "lib users" (shared-library users) section |
| `Esc` | Back out to the package list |

Toggle letters are assigned in the order the detail source declares them
(`PackageDetailSource#toggles`), not mnemonically — `a` is always the first
toggle, `b` the second, regardless of what they're labeled.

## Errors and dismissing popups

If `A` fails (locked packages, permission denied, etc.), an error popup
appears. Any key dismisses it and returns focus to the package table.
