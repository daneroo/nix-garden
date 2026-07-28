# Keybindings

macOS-equivalence keybinding map, tuned and validated on `gauss` and `hardy`
2026-07-23. This page states the settled facts; Git history retains the full
Gauss validation, Hardy backport, mechanism comparisons, and bugs found.

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

Gauss still uses Brave's native Ctrl defaults for copy/paste, address focus, and
Find. Hardy's dedicated focus-sensitive mapper closes those gaps, so Super+L and
Super+F work there and not on Gauss. This asymmetry is unfinished work, not a
chosen end state: the reason Gauss was left on Ctrl defaults is no longer
recorded, and the intended behavior is the same on both hosts. Closing it
belongs to
[simplified-keybinding-model](../thoughts/design/simplified-keybinding-model.md),
which already lists Brave's contextual map as shared. Do not treat the Gauss
column as a requirement to preserve.

Hardy also provides Super+Shift+W as a tested close-window convenience, but it
is not presented as macOS equivalence: macOS uses contextual Cmd+W rather than a
separate standard close-window chord.

On Gauss, the application mapper also provides a best-effort Super+W → Ctrl+W
catch-all for apps other than Ghostty and Brave. Linux has no universal
quit/close convention, so this is not claimed as exhaustive.

## GNOME functions

| Function              | macOS         | `gauss`                   | `hardy`                       |
| --------------------- | ------------- | ------------------------- | ----------------------------- |
| Switch applications   | Cmd+Tab       | Super+Tab                 | Super+Tab                     |
| Lock                  | Ctrl+Cmd+Q    | Super+Shift+L             | Ctrl+Super+Q                  |
| Log out               | Cmd+Shift+Q   | no declared equivalent    | Super+Shift+Q                 |
| Full-screen capture   | Cmd+Shift+3   | Shift+Print               | Super+Shift+3                 |
| Screenshot selection  | Cmd+Shift+4   | Print screenshot UI       | Super+Shift+4                 |
| Keyboard illumination | hardware keys | hardware-specific/default | Super+F6/F7 from physical Alt |

Hardy preserves GNOME's original Print variants and Super+Shift+L lock as
fallbacks. Its screenshot and lock rows use physical Alt as Super/Cmd, so the
physical positions match macOS. Logout is also forced visible in GNOME's system
menu; Super+Shift+Q opens the standard confirmation dialog rather than ending
the session immediately.

## Known gaps

- No date-math found in any launcher candidate tried (Vicinae, Ulauncher).
- Vicinae's clipboard history needs its own separate GNOME extension
  ([dagimg-dot/vicinae-gnome-extension](https://github.com/dagimg-dot/vicinae-gnome-extension)),
  not yet pursued — degrades gracefully to no clipboard history rather than
  failing.
- Address-bar focus and Find cannot be supplied by Chromium's extension API.
  Gauss keeps Brave's Ctrl+L/Ctrl+F defaults; Hardy's focus-sensitive `keyd`
  mapper translates them.
- Hardy's 1Password desktop app, Quick Access, browser-support wrapper, and
  Brave extension handshake are validated.

## Debugging

- Runtime overrides applied by `keyd bind` survive the process that issued them.
  Restart the `keyd` service before judging a clean configuration.
- Local dconf values override declared system defaults. Inspect effective values
  and use `gsettings reset` to remove a stale local override rather than writing
  another one.

## Adjacent state

- `programs.firefox.enable` dropped (confirmed unused) on both hosts.
- `org.gnome.shell.favorite-apps` pinned to Ghostty, Brave, and Files.
- GNOME's existing `Super+Alt+Left/Right` / `Ctrl+Alt+Left/Right`
  workspace-switch defaults already map cleanly onto Daniel's
  Cmd+Option+Left/Right muscle memory once the modifier swap is applied — no new
  binding needed.
