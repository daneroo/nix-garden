# Keybindings

macOS-equivalence keybinding map, tuned and validated on `gauss` 2026-07-23.
`hardy` (Chromebook keyboard, no physical Cmd/Super key) has its own backport
ticket and plan — see
[hardy-keybinding-backport](../thoughts/tickets/hardy-keybinding-backport.md);
this doc will be refined once that lands. Full validation trail, mechanism
comparisons, and bugs found stay in
[keybinding-model](../thoughts/tickets/keybinding-model.md) (git history); this
page states only the settled facts.

## Modifier mapping

Physical Alt (next to Space, matching a real MacBook's Cmd position) acts as the
Cmd-equivalent `Super` modifier — matching Daniel's own macOS modifier swap.
Physical Super/Win acts as the Option-equivalent `Alt`. Implemented via
[`services.keyd`](https://github.com/rvaiya/keyd) (`hosts/gauss/default.nix`),
not xkb — `keyd` operates below the compositor and is required anyway for
per-application remapping (see Mechanism below).

## Mechanism

- **Ghostty** — native per-app config (`~/.config/ghostty/config`, deployed via
  `systemd.tmpfiles.rules`). No remap layer needed.
- **Brave** — Chromium hard-rejects Super/Meta as an extension-shortcut modifier
  on every platform, so native config alone is insufficient.
  [`keyd-application-mapper`](https://github.com/rvaiya/keyd) retranslates
  Super-based chords into Brave's own native Ctrl-based ones, but only while a
  Brave window has focus (a patched GNOME Shell extension feeds it window-focus
  events — GNOME's Shell extension only officially supports up to version 49;
  this system runs 50.2, patched and confirmed working).
- **Launcher** — [Vicinae](https://vicinae.com), chosen over Ulauncher (kept as
  a documented lighter fallback, not installed) and rofi (ruled out —
  hard-requires the wlr-layer-shell protocol GNOME's Mutter doesn't implement).
- **1Password** — its own `--quick-access` CLI flag, no remapping needed.

## Equivalence map

| Function                                       | macOS                        | Ghostty                                                             | Brave                    | Launcher    | 1Password         |
| ---------------------------------------------- | ---------------------------- | ------------------------------------------------------------------- | ------------------------ | ----------- | ----------------- |
| Copy                                           | Cmd+C                        | Super+C                                                             | Ctrl+C (browser default) |             |                   |
| Paste                                          | Cmd+V                        | Super+V                                                             | Ctrl+V (browser default) |             |                   |
| New tab                                        | Cmd+T                        | Super+T                                                             | Super+T                  |             |                   |
| Close tab                                      | Cmd+W                        | Super+W                                                             | Super+W                  |             |                   |
| Reopen closed tab                              | Cmd+Shift+T                  | n/a                                                                 | Super+Shift+T            | n/a         | n/a               |
| New window                                     | Cmd+N                        | Super+N                                                             | Super+N                  |             |                   |
| Next tab                                       | Cmd+Shift+] / Ctrl+Tab       | Super+Shift+]                                                       | Super+Shift+]            |             |                   |
| Previous tab                                   | Cmd+Shift+[ / Ctrl+Shift+Tab | Super+Shift+[                                                       | Super+Shift+[            |             |                   |
| Close window (other apps)                      | n/a (Cmd+W is contextual)    | n/a                                                                 | n/a                      |             |                   |
| Address-bar focus                              | Cmd+L                        | n/a                                                                 | Ctrl+L (browser default) | n/a         | n/a               |
| Find                                           | Cmd+F                        | n/a                                                                 | Ctrl+F (browser default) | n/a         | n/a               |
| Clear / scrollback                             | Cmd+K                        | Super+K                                                             | n/a                      | n/a         | n/a               |
| Quit app                                       | Cmd+Q                        | Super+Q                                                             |                          |             |                   |
| Launcher invoke                                | Cmd+Space                    | n/a                                                                 | n/a                      | Super+Space | n/a               |
| Autofill / password                            | Cmd+Shift+Space              | n/a                                                                 | via browser extension    | n/a         | Super+Shift+Space |
| Close window (generic apps, not Ghostty/Brave) | n/a                          | Super+W → Ctrl+W (best-effort catch-all, not exhaustively verified) |                          |             |                   |

Copy/Paste in Brave intentionally left on the browser default (Ctrl+C/V) — a
real, logged gap, not urgent since it already works.

## Known gaps

- No date-math found in any launcher candidate tried (Vicinae, Ulauncher).
- Vicinae's clipboard history needs its own separate GNOME extension
  ([dagimg-dot/vicinae-gnome-extension](https://github.com/dagimg-dot/vicinae-gnome-extension)),
  not yet pursued — degrades gracefully to no clipboard history rather than
  failing.
- Address-bar focus and Find in Brave have no extension API reaching them; kept
  on Brave's own Ctrl+L/Ctrl+F defaults.

## Adjacent state

- `programs.firefox.enable` dropped (confirmed unused) on both hosts.
- `org.gnome.shell.favorite-apps` pinned to Ghostty, Brave, and Files.
- GNOME's existing `Super+Alt+Left/Right` / `Ctrl+Alt+Left/Right`
  workspace-switch defaults already map cleanly onto Daniel's
  Cmd+Option+Left/Right muscle memory once the modifier swap is applied — no new
  binding needed.
