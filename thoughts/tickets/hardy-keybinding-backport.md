# hardy-keybinding-backport

Carries forward the `hardy`-specific work split out of `keybinding-model` when
that ticket closed 2026-07-23 (validated and settled on `gauss`). See
[keybinding-model](keybinding-model.md) for the full validation trail, mechanism
comparisons, and bugs found — this ticket only tracks what's specific to
`hardy`.

## End state

- 1Password is installed again through the correct NixOS modules, its desktop
  app works, and Brave's extension can communicate with it.
- The physical keyboard is illuminated at a useful level after boot, and its
  brightness-down/up controls work without compromising the chosen modifier
  model.
- Brave and Ghostty are fully usable for Daniel's daily reflexes.
- The internal Chromebook keyboard has the sanest achievable mapping of
  Cmd-equivalent, Option, and native Control roles, based on observed key events
  rather than Gauss assumptions.
- Launcher, lock, screenshot, app/window switching, and the settled app bindings
  have been validated live on Hardy's physical keyboard.
- Differences from Gauss or macOS are deliberate, documented, and less costly
  than the mechanism that would be required to erase them.

## Execution topology

- Coordinate configuration, builds, service inspection, and other non-physical
  validation from the current workspace over SSH to `daniel@192.168.2.40`.
- Use the LAN address until Tailscale is running and `hardy.ts.imetrical.com`
  exists. Do not plan around `hardy.imetrical.com`; a Bell Giga Hub reservation
  bug currently prevents a stable LAN DNS path under that name, and fixing the
  router is out of scope.
- When progress requires physical key presses or feel judgments, hand off the
  exact current state, remaining commands, test matrix, and expected
  observations to Codex running locally on Hardy. Daniel will assist with the
  physical input and subjective validation.

## Why this is its own ticket, not a keybinding-model step

Daniel did not want `hardy` work happening on the now-closed `keybinding-model`
branch. `hardy` backport is real, separate work with its own constraint (see
below), not a continuation of the merged branch.

## Current regression to repair first

After applying merged `main` to `hardy` on 2026-07-23, 1Password disappeared as
expected from the closure: the shared plain `_1password-gui` package was removed
when Gauss adopted the proper NixOS module, but Hardy did not receive that
module. Restore it before keyboard experimentation so Hardy returns to its prior
functional baseline.

Restored on the execution branch with both NixOS modules and
`polkitPolicyOwners = [ "daniel" ]`. Hardy's closure gained only the expected
GUI, CLI, and wrappers; `1Password-BrowserSupport` is the expected
`root:onepassword` setgid wrapper. Daniel confirmed the GUI launches,
authentication works, and his account is connected. The Brave-extension
handshake remains part of final application validation.

## Keyboard backlight regression

Reported on Hardy 2026-07-23: the keyboard-backlight buttons no longer worked
and the keyboard was dark.

Initial remote inspection from Galois established:

- Linux 6.18.39 still exposes the correct ChromeOS EC LED device at
  `/sys/class/leds/chromeos::kbd_backlight`, with `max_brightness = 100`.
- Its brightness was `0`; writing `50` succeeded immediately, so the LED,
  firmware interface, and `cros_kbd_led_backlight` path are functional.
- `systemd-backlight@leds:chromeos::kbd_backlight.service` loaded successfully,
  but its saved state in `/var/lib/systemd/backlight` was also zero.
- Setting and saving `50/100` survived the subsequent 1Password system switch;
  the hardware and systemd persistence path are therefore working.
- UPower exposes `org.freedesktop.UPower.KbdBacklight`, so a standard userspace
  control path is available.
- The kernel separately reports
  `cros-ec-keyb GOOG0007:00: cannot register non-matrix inputs: -95`. That is a
  plausible cause of missing special-key events, but it is not yet proven to be
  the button regression.

Physical `evtest` capture then established:

- Search/Launcher emits `KEY_LEFTMETA`; the keyboard has no Super-labelled key,
  but it does provide a native Meta event.
- Left Ctrl and left Alt emit their standard native events.
- The screen-brightness-down/up keys emit plain `KEY_F6` / `KEY_F7`, both alone
  and while left Alt is held. The events are present; userspace simply was not
  translating ChromeOS's Alt+brightness convention into keyboard-illumination
  events.
- `keyd monitor` identifies the internal keyboard as `0001:0001:09b4e68d`. Use
  that exact device instead of a wildcard for the backlight mapping.

The deployed fix scopes `keyd` to that device and maps physical `Alt+F6/F7` to
standard `kbdillumdown/up` events. Daniel confirmed repeated level changes and
GNOME's native keyboard-illumination OSD; the live EC value changed accordingly.
Plain F6/F7 and every modifier role remain unchanged in this independently
deployable checkpoint.

Treat illumination and button handling as separate layers. First preserve a
useful nonzero level across reboot. Then capture the physical backlight chords
and determine whether Hardy emits keyboard-illumination events, ordinary
brightness events, function keys, or nothing. Do not choose a keyd mapping from
the kernel log alone.

## Constraint

`hardy` has no physical Cmd/Super-labelled key (Chromebook keyboard, ASUS Flip
C436F), but its Search/Launcher key has now been observed emitting native
`KEY_LEFTMETA`. This is still physically different from `gauss`'s standard PC
keyboard: re-validate which physical positions should provide Cmd-equivalent,
Option, and native Control rather than copying Gauss's symmetric mapping
unchanged.

## Modifier capture and reversible trial

Raw capture established that both Alt keys, both Ctrl keys, and Search are
independently available. Search emits `KEY_LEFTMETA`; there is no physical
right-Meta key.

The first in-memory trial therefore maps both physical Alt keys beside Space to
Meta/Cmd, maps Search to Alt/Option, and leaves both Ctrl keys native.
`keyd monitor` confirmed the resulting output exactly, and moving the
illumination bindings from the Alt layer to the Meta layer preserved physical
Alt+brightness-down/up. This provides all three roles without asking a native
Linux Ctrl key to do double duty. Daniel confirmed physical Alt+Tab is his
established muscle-memory choice, so this is the base map to make declarative.
Search's physical Caps-Lock position makes Caps Lock an interesting future
alternative, including for cross-platform symmetry with macOS, but that is a
later refinement rather than a reason to discard Hardy's only distinct Option
role now.

The mapping is now declarative and active, scoped to the exact internal-keyboard
ID. External keyboards deliberately retain their native events until one is
actually attached and assessed; the internal Chromebook constraint should not
silently rewrite them.

One NixOS-specific trap surfaced during the next checkpoint: creating the
otherwise conventional empty `keyd` group made keyd 2.6.0 find the group and
attempt `setgid`, but the hardened NixOS unit rejects that operation
(`setgid: Operation not permitted`). The daemon then entered a restart loop.
Deleting the newly created group restored service immediately, and the
declaration was removed in the next commit. The harmless startup warning about
the absent group remains for the base static mapping. Any future application
mapper work must solve socket access together with the unit hardening rather
than adding the group alone or copying Gauss's broad `Group = "users"` override.

## Desktop binding checkpoint

Ghostty's validated native Super bindings and scroll multipliers are now
deployed on Hardy. Vicinae 0.23.1 is installed, its user service is active, and
GNOME has declarative physical-Cmd equivalents for Vicinae (`<Super>space`) and
1Password Quick Access (`<Super><Shift>space`). The corresponding GNOME
collisions are freed, lock is moved to `<Super><Shift>l`, and Ghostty, Brave,
and Files are the declared favorites.

The local-only dconf inventory found no user overrides for the new shortcuts. It
did find stale local values for GNOME favorites and AC suspend timeout/type;
only those three values were reset. The declared favorites, timeout `0`, and
type `nothing` are now effective. Logout/reboot survival and live physical
acceptance remain to be proven.

The first physical baseline pass before a session refresh confirmed:

- Ghostty's Cmd-equivalent bindings worked except physical Alt+V, which the old
  GNOME session still intercepted as its Super+V calendar shortcut.
- Physical Alt+Space did not yet invoke Vicinae for the same reason.
- Physical Alt+Tab and Search+Tab both switched apps. This preserves the desired
  Cmd-position reflex while Search remains a real native-Alt/Option role.
- Brave's native Ctrl+T worked and physical Alt+T did not, directly proving the
  need for the focus-sensitive mapper rather than assuming Gauss's result.
- 1Password's app worked. Brave had not yet restored Daniel's Sync chain, so no
  browser extensions existed and the integration handshake could not yet be
  tested.
- Physical Alt+F6/F7 repeatedly changed keyboard illumination.

The mapper checkpoint uses a dedicated `keyd` group, `0660 root:keyd` socket,
and only adds `CAP_SETGID` to NixOS's existing capability bounding set. Hardy's
patched GNOME 50 extension became active after logout and started
`keyd-application-mapper`; a reboot was then required because the long-lived
systemd user manager retained its pre-group supplementary groups across the
GNOME-only logout.

The reboot supplied the full persistence checkpoint: the selected keyboard
illumination level returned at `30/100` and systemd's saved value was also 30;
the declared NixOS generation booted; keyd started cleanly with the exact
internal keyboard; `/run/keyd.socket` returned as `0660 root:keyd`; and the user
manager, GNOME Shell, and mapper all had the dedicated group. The patched
extension and Vicinae service were active, and the declared dconf bindings were
effective. Final per-app physical validation remains.

## Carried-forward facts

- **Alternative base-layer strategy to consider**: the
  `stevenilsen123/mac-keyboard-behavior-in-linux` project swaps Ctrl↔Meta for
  Mac keyboards but Ctrl↔Alt for Windows/Linux keyboards, treating physical Alt
  as Command in the latter case. Hardy fits neither assumption cleanly until its
  Search/Launcher and modifier events are observed. The useful hypothesis is
  narrower: a Cmd-position physical key that emits native `Ctrl` may use common
  Linux shortcuts directly and sidestep much of the per-app remapping Gauss
  needed. Test that hypothesis first; do not assume a particular symmetric swap.
- **`programs._1password-gui` module**: 1Password was moved out of the shared
  `flake.nix` `bootstrapPackages` during `keybinding-model` work. Hardy now has
  the same proper module treatment as Gauss. The module installs the
  `1Password-BrowserSupport` setgid wrapper required for browser integration;
  `polkitPolicyOwners` separately enables the package's polkit integration for
  Daniel. GUI launch, authentication, and account connection are confirmed; live
  Brave integration remains.
- **`keyd` GNOME Shell extension version**: `gauss` needed patching (upstream
  only declares Shell 45-49 support). It is only relevant if Hardy still needs
  `keyd-application-mapper`; if so, check Hardy's actual GNOME Shell version
  before assuming the same patch is needed unchanged.
- **Mutable dconf state**: system dconf databases provide defaults, while local
  user values win unless locked. Inventory effective values and local overrides
  before diagnosing a binding failure or declaring the result converged.
- Full settled `gauss` equivalence map:
  [docs/keybindings.md](../../docs/keybindings.md).

## Documentation cleanup in scope

Harvesting Hardy's result is also the right time to fix the small
inconsistencies found in the merged durable documentation: the close-window
rows, the stale Chrome-extension rationale for gaps that
`keyd-application-mapper` could reach, the old ticket's incomplete capture note,
1Password wrapper terminology, and the missing docs index entries. This cleanup
clarifies the two-host result and does not expand the runtime implementation.

## Not carried forward (deliberately)

- Multi-day real-use stability iteration on `gauss` — not a todo. Issues surface
  naturally; log them in `BACKLOG.md` as they come up, and open a new
  ticket/plan only if enough accumulate to warrant one.
