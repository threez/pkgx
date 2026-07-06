# Development

```sh
crystal spec                          # unit specs — no real pkg db touched
crystal build --no-codegen src/pkgx.cr # fast compile-only check
shards build
```

Specs require source files directly (e.g. `require "../src/pkgx/browser"`)
rather than the top-level `pkgx` shard — `src/pkgx.cr` unconditionally
calls `Pkgx::App.run` at the bottom, which would launch the real
interactive TUI as a require-time side effect if pulled in by a spec.

`Browser#apply`'s only CI-safe path is the empty-work-list early return
(asserted in `spec/browser_spec.cr`) — everything past that needs a real,
writable, rootful `pkg` database with no mocking seam in `freebsd.cr`, so
it's manual/live-verification only. Do this via `./bin/pkgx` in a real
terminal or tmux (never a hand-rolled script bypassing `TUI::Runtime`),
and never run `A` against a real system database outside of an explicit,
separately-supervised, disposable environment — it's destructive.
