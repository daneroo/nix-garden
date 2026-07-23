# Keybindings

macOS-equivalence keybinding map, tuned and validated on `gauss` and `hardy`
2026-07-23. Hardy's full execution evidence is in
[hardy-keybinding-backport](../thoughts/tickets/hardy-keybinding-backport.md).
Full Gauss validation, mechanism comparisons, and bugs found stay in
[keybinding-model](../thoughts/tickets/keybinding-model.md) (git history); this
page states only the settled facts.

## Modifier mapping

Both hosts make physical Alt (next to Space, matching a real MacBook's Cmd
position) the Cmd-equivalent `Super` modifier, matching Daniel's macOS modifier
swap. The Option role depends on the physical keyboard:

| Host    | Physical Ctrl | Physical Alt  | Physical Win/Search | Scope                  |
| ------- | ------------- | ------------- | ------------------- | ---------------------- |
| `gauss` | native Ctrl   | Cmd / `Super` | Option / `Alt`      | all attached keyboards |
| `hardy` | native Ctrl   | Cmd / `Super` | Option / `Alt`      | internal keyboard only |

Hardy's Chromebook keyboard has no Cmd-labelled key, but raw capture proved its
Search key emits `KEY_LEFTMETA`; `keyd` turns that distinct key into Option
while preserving native Ctrl. External keyboards on Hardy remain native until
one is attached and assessed.

Both mappings use [`services.keyd`](https://github.com/rvaiya/keyd), not xkb.
`keyd` operates below the compositor and is also the established mechanism for
focus-sensitive application remapping.

## Mechanism

- **Ghostty** — native per-app config (`~/.config/ghostty/config`, deployed via
  `systemd.tmpfiles.rules`). No remap layer needed.
- **Brave** — Chromium hard-rejects Super/Meta as an extension-shortcut modifier
  in its `chrome.commands` extension API, so an extension alone is insufficient.
  [`keyd-application-mapper`](https://github.com/rvaiya/keyd) retranslates
  Super-based chords into Brave's own native Ctrl-based ones, but only while a
  Brave window has focus (a patched GNOME Shell extension feeds it window-focus
  events — GNOME's Shell extension only officially supports up to version 49;
  both hosts run 50.2, patched and confirmed working). Hardy uses a dedicated
  `keyd` group and a `0660 root:keyd` socket; Gauss's broader socket permission
  is tracked separately for security cleanup.
- **Launcher** — [Vicinae](https://vicinae.com), chosen over Ulauncher (kept as
  a documented lighter fallback, not installed) and rofi (ruled out —
  hard-requires the wlr-layer-shell protocol GNOME's Mutter doesn't implement).
- **1Password** — its own `--quick-access` CLI flag, no remapping needed.

## Equivalence map

| Function               | macOS                        | Ghostty       | Brave (`gauss`)          | Brave (`hardy`) | Launcher    | 1Password         |
| ---------------------- | ---------------------------- | ------------- | ------------------------ | --------------- | ----------- | ----------------- |
| Copy                   | Cmd+C                        | Super+C       | Ctrl+C (browser default) | Super+C         |             |                   |
| Paste                  | Cmd+V                        | Super+V       | Ctrl+V (browser default) | Super+V         |             |                   |
| New tab                | Cmd+T                        | Super+T       | Super+T                  | Super+T         |             |                   |
| Close tab              | Cmd+W                        | Super+W       | Super+W                  | Super+W         |             |                   |
| Reopen closed tab      | Cmd+Shift+T                  | n/a           | Super+Shift+T            | Super+Shift+T   | n/a         | n/a               |
| New window             | Cmd+N                        | Super+N       | Super+N                  | Super+N         |             |                   |
| Next tab               | Cmd+Shift+] / Ctrl+Tab       | Super+Shift+] | Super+Shift+]            | Super+Shift+]   |             |                   |
| Previous tab           | Cmd+Shift+[ / Ctrl+Shift+Tab | Super+Shift+[ | Super+Shift+[            | Super+Shift+[   |             |                   |
| Close window / context | Cmd+W                        | Super+W       | Super+W                  | Super+W         | n/a         | n/a               |
| Address-bar focus      | Cmd+L                        | n/a           | Ctrl+L (browser default) | Super+L         | n/a         | n/a               |
| Find                   | Cmd+F                        | n/a           | Ctrl+F (browser default) | Super+F         | n/a         | n/a               |
| Clear / scrollback     | Cmd+K                        | Super+K       | n/a                      | n/a             | n/a         | n/a               |
| Quit app               | Cmd+Q                        | Super+Q       |                          |                 |             |                   |
| Launcher invoke        | Cmd+Space                    | n/a           | n/a                      | n/a             | Super+Space | n/a               |
| Autofill / password    | Cmd+Shift+Space              | n/a           | via browser extension    | via extension   | n/a         | Super+Shift+Space |

Gauss intentionally leaves Brave copy/paste, address focus, and Find on native
Ctrl defaults. Hardy's dedicated focus-sensitive mapper closes those gaps. Hardy
also provides Super+Shift+W as a tested close-window convenience, but it is not
presented as macOS equivalence: macOS uses contextual Cmd+W rather than a
separate standard close-window chord.

On Gauss, the application mapper also provides a best-effort Super+W → Ctrl+W
catch-all for apps other than Ghostty and Brave. Linux has no universal
quit/close convention, so this is not claimed as exhaustive.

## GNOME functions

| Function              | macOS         | `gauss`                   | `hardy`                       |
| --------------------- | ------------- | ------------------------- | ----------------------------- |
| Switch applications   | Cmd+Tab       | Super+Tab                 | Super+Tab                     |
| Lock                  | Ctrl+Cmd+Q    | Super+Shift+L             | Ctrl+Super+Q                  |
| Full-screen capture   | Cmd+Shift+3   | Shift+Print               | Super+Shift+3                 |
| Screenshot selection  | Cmd+Shift+4   | Print screenshot UI       | Super+Shift+4                 |
| Keyboard illumination | hardware keys | hardware-specific/default | Super+F6/F7 from physical Alt |

Hardy preserves GNOME's original Print variants and Super+Shift+L lock as
fallbacks. Its screenshot and lock rows use physical Alt as Super/Cmd, so the
physical positions match macOS.

## Known gaps

- No date-math found in any launcher candidate tried (Vicinae, Ulauncher).
- Vicinae's clipboard history needs its own separate GNOME extension
  ([dagimg-dot/vicinae-gnome-extension](https://github.com/dagimg-dot/vicinae-gnome-extension)),
  not yet pursued — degrades gracefully to no clipboard history rather than
  failing.
- Address-bar focus and Find cannot be supplied by Chromium's extension API.
  Gauss keeps Brave's Ctrl+L/Ctrl+F defaults; Hardy's focus-sensitive `keyd`
  mapper translates them.
- Hardy's 1Password desktop app, Quick Access, and browser-support wrapper are
  validated. Its Brave extension handshake remains pending until Brave Sync
  restores the extension.

## Adjacent state

- `programs.firefox.enable` dropped (confirmed unused) on both hosts.
- `org.gnome.shell.favorite-apps` pinned to Ghostty, Brave, and Files.
- GNOME's existing `Super+Alt+Left/Right` / `Ctrl+Alt+Left/Right`
  workspace-switch defaults already map cleanly onto Daniel's
  Cmd+Option+Left/Right muscle memory once the modifier swap is applied — no new
  binding needed.
