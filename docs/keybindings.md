# Keybindings

Daniel's shortcut layout keeps the physical key beside Space in the role learned
from macOS. On both managed NixOS hosts that key is Alt, and the active
configuration describes it precisely as Alt rather than translating it through
another modifier.

The native-Alt model was validated on Hardy and Gauss on 2026-07-28. Git history
retains the earlier experiments and the former implementation, which carried
physical Alt through Linux Super before translating selected application chords
again.

## Modifier Ownership

| Physical key                             | Logical modifier | Ownership                                     |
| ---------------------------------------- | ---------------- | --------------------------------------------- |
| Alt beside Space                         | Alt              | Covered application and desktop shortcuts     |
| Ctrl                                     | Ctrl             | Native terminal and application Control input |
| Hardy Search / Gauss Windows-logo        | Super            | Native GNOME behavior                         |
| Right Alt, or AltGr when a layout has it | Native           | Unclaimed by the shared model                 |

Neither host has a base Alt-to-Super mapping. Stock GNOME Super bindings that
were displaced by the former carrier are available again, including Super+N,
Super+V/Super+M, Super+Space, Super+L, and Super+Tab.

Hardy's internal keyboard is identified by its observed keyd device ID only for
the Chromebook-specific Alt+F6/F7 illumination chords. Ctrl, Alt, and Search
remain native on that keyboard. Gauss leaves every attached keyboard's base
modifiers native.

## Mechanism

- **Ghostty** binds native Alt directly in its own configuration.
- **Brave** uses Ctrl for the covered Linux actions. The focused
  `keyd-application-mapper` translates only the declared native Alt chords while
  Brave has focus. A patched keyd GNOME Shell extension supplies focus changes
  on GNOME Shell 50. No unnamed application receives this translation.
- **GNOME** owns the covered desktop actions through direct Alt bindings.
  Vicinae takes Alt+Space, so GNOME's conflicting active-window-menu shortcut is
  explicitly empty.
- **Vicinae** uses a GNOME custom shortcut to call `vicinae toggle`.
- **1Password** uses a GNOME custom shortcut to call its own `--quick-access`
  entry point. Brave autofill still depends on the existing browser extension
  and desktop-app handshake.

keyd remains necessary for Brave's focus-sensitive translation and for Hardy's
internal-keyboard illumination adapter. It no longer changes the base modifier
identity.

## Application Map

| Function          | Ghostty     | Brave       |
| ----------------- | ----------- | ----------- |
| Copy              | Alt+C       | Alt+C       |
| Paste             | Alt+V       | Alt+V       |
| New tab           | Alt+T       | Alt+T       |
| Close tab/context | Alt+W       | Alt+W       |
| Reopen closed tab | —           | Alt+Shift+T |
| New window        | Alt+N       | Alt+N       |
| Next tab          | Alt+Shift+] | Alt+Shift+] |
| Previous tab      | Alt+Shift+[ | Alt+Shift+[ |
| Address-bar focus | —           | Alt+L       |
| Find              | —           | Alt+F       |
| Clear screen      | Alt+K       | —           |
| Quit              | Alt+Q       | Unmapped    |

Brave deliberately has no Alt+Shift+W or Alt+Q mapping. Alt+W is the single
close path; closing its final tab closes the window. The mapper explicitly
passes Alt+Shift+L through as Alt+Shift+L so the global lock chord still works
while Brave is focused.

Ghostty leaves unbound Alt chords as terminal Alt input. The E2E fixture proves
that Alt+D reaches the PTY as an Alt sequence and that Ctrl+C remains native
Control-C. Files is the stock-GNOME negative control: its normal Ctrl shortcuts
remain native, and it does not inherit Brave's Alt translation.

## Desktop Map

| Function               | Physical chord                     | Notes                                        |
| ---------------------- | ---------------------------------- | -------------------------------------------- |
| Switch applications    | Alt+Tab                            | Native GNOME binding; Super+Tab also remains |
| Vicinae                | Alt+Space                          | GNOME window-menu binding is cleared         |
| 1Password Quick Access | Alt+Shift+Space                    | Requires the desktop app to be running       |
| Lock                   | Alt+Shift+L                        | Super+L and Ctrl+Alt+Q remain fallbacks      |
| Log out                | Alt+Shift+Q                        | Opens GNOME's confirmation dialog            |
| Full-screen capture    | Alt+Shift+3                        | Shift+Print remains a fallback               |
| Screenshot selection   | Alt+Shift+4                        | Print remains a fallback                     |
| Switch workspace       | Alt+Search/Windows-logo+Left/Right | GNOME's native Super+Alt workspace binding   |
| Keyboard illumination  | Hardy internal Alt+F6/F7           | Device-scoped; no Gauss adapter              |

The same physical application and desktop map is declared on both hosts. Hardy's
only intended keybinding-specific delta is its internal-keyboard illumination
adapter.

## Validation Boundary

The shared headless suite passed 27/27 against both host configurations at
feature closeout. It proves distinct Alt, Ctrl, and Super delivery; absence of
the old carrier; declared GNOME and application bindings; semantic Ghostty and
Brave behavior; and native Ctrl/terminal Alt paths. Guided cases and their
limits are documented in [End-to-End Testing](e2e-testing.md).

Real-hardware acceptance covered the complete shared map on both hosts,
including Brave focus transitions, Files as the negative control, 1Password,
logout/login, and reboot persistence. Gauss also passed its external-keyboard
and right-Alt checks. Hardy's internal keyboard passed, including illumination,
but its external-keyboard comparison was explicitly deferred and remains a
follow-up.

## Known Gaps

- Complete Hardy external-keyboard validation remains open. Its declarations
  leave external base modifiers native, but the physical Brave, workspace,
  right-Alt/AltGr, and illumination-isolation pass has not been performed.
- The visible VM does not show the guided Alt+Shift+L lock or Alt+Shift+Q logout
  consequences even though the injected events are correct and both chords work
  on real Gauss. See
  [visible-vm-session-actions](../thoughts/tickets/visible-vm-session-actions.md).
- Vicinae's clipboard history still needs its separate GNOME extension and is
  not part of this model.

## Debugging

- Runtime overrides applied by `keyd bind` survive the process that issued them.
  Restart keyd before judging a clean declarative configuration.
- Local dconf values override declared system defaults. Compare declared and
  effective values, then reset only identified stale keys; stale carrier-era
  overrides had to be removed on both hosts during this migration.
- Mapper health is diagnostic, not behavioral proof. Check the GNOME extension,
  `keyd-application-mapper`, and `~/.config/keyd/app.conf`, then reproduce the
  focused application consequence.
