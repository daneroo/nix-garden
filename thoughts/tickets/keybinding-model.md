# keybinding-model

Working detail for the `keybinding-model` backlog item: a macOS-equivalence
keybinding map for the apps and functions Daniel uses daily, tuned on `gauss`
and backported to `hardy`.

This repo has never done keybinding-remap work before. Nothing below is a
decision — every mechanism question is an open experiment to run and validate on
`gauss`, biased toward the simplest thing that works. Do not adopt a heavier
mechanism (e.g. a global remap layer, Home Manager, wrapped programs) until a
simpler one (native per-app config, GNOME custom keybindings) has been tried and
shown insufficient. Record what was tried and why it was kept or dropped, not
just the final answer.

## Scope

Apps (per `flake.nix` `bootstrapPackages` and `xdg.mime.defaultApplications`,
verified 2026-07-23 against `origin/main` at `80bdff4` — packages already
installed fleet-wide; only the keybinding scheme is open):

- Ghostty (terminal) — package present, bindings not yet designed.
- Brave (browser) — package present and set as default handler for
  `text/html`/`http`/`https`/`about`/`unknown` MIME types. The
  `hosts/*/default.nix` `programs.firefox.enable = true;` lines are a stale
  leftover, not an active competing target — flag for cleanup (drop, or record
  an explicit reason to keep Firefox installed alongside Brave).
- 1Password (`_1password-gui`) — package present, bindings not yet designed;
  browser-extension pairing with Brave still needs verifying.
- Raycast-equivalent launcher — **not present in `flake.nix`**; candidate NixOS
  options need evaluation: e.g. `rofi`/`wofi`, `ulauncher`, `krunner`, GNOME's
  built-in Activities search as the zero-install baseline to beat.

Functions (minimum set, expand as gaps surface):

- Copy / paste
- New tab / close tab
- New window / close window
- Next tab / previous tab
- (Add during research: switch window, switch app, quit app, spotlight/search,
  screenshot, lock screen, and any other chord Daniel reaches for reflexively on
  macOS)

Out of scope for this ticket: compositor-level tiling/workspace bindings tied to
`compositor-selection` (Niri vs Hyprland) — GNOME is the current baseline on
both hosts, so this map targets GNOME first and flags which entries are
WM-dependent for later porting.

## Constraints

- `hardy` has no Cmd/Super key (Chromebook layout) — a known confound. Per
  [homelab-platform](../design/homelab-platform.md), all tuning happens on
  `gauss` (standard keyboard) first; `hardy` only receives the finished map.
- Existing research:
  [desktop-test-harness-fidelity](../research/desktop-test-harness-fidelity.md)
  establishes the test fidelity ladder (L0 nested compositor, L1 QEMU VM, L2
  hardware specialisation, L3 dedicated metal) and the objective instruments
  (`wev`, `keyd monitor`, `libinput debug-events`) for verifying what a channel
  actually delivers versus how it feels. Judgment on binding _feel_ requires L2
  (real hardware) or better — VNC/VM alone is disqualified for that call. Use
  the same instruments to validate whatever mechanism gets tried here, not just
  to judge feel.
- No prior research specific to per-app binding schemes (Ghostty, launcher
  candidates, 1Password) exists yet in this repo — treat as open.

## Mechanism candidates (unvalidated — experiment before choosing)

An earlier repo review
([claude-initial-impressions-and-guidance](../reviews/claude-initial-impressions-and-guidance.md#desktop-and-keybindings))
floated these; they are starting hypotheses, not conclusions:

- **Per-app native config** (GNOME custom keybindings, Ghostty's own keybind
  config, Brave's own settings/policy, 1Password's own settings) — try first;
  simplest, no new system component.
- **Global remap layer** (`services.keyd` or similar) — only if per-app config
  can't deliver a consistent Cmd-like modifier across apps that don't expose
  independent keybinding config.
- **Home Manager** — only if user-space config genuinely needs its module
  system; do not adopt as a default "desktop work is starting" ritual.
- **Wrapped programs**
  ([module-architecture](../research/module-architecture.md)) — only relevant if
  a binding needs to be portable to `galois` (macOS) too, which is not yet an
  established requirement here.

Record, per candidate actually tried: what was tested, the command/config used,
the observed result (pass/fail per the fidelity-ladder instruments), and whether
it was kept.

## Equivalence map (fill in during research)

| Function            | macOS                        | Ghostty | Brave | Launcher | 1Password | Notes |
| ------------------- | ---------------------------- | ------- | ----- | -------- | --------- | ----- |
| Copy                | Cmd+C                        |         |       |          |           |       |
| Paste               | Cmd+V                        |         |       |          |           |       |
| New tab             | Cmd+T                        |         |       |          |           |       |
| Close tab           | Cmd+W                        |         |       |          |           |       |
| New window          | Cmd+N                        |         |       |          |           |       |
| Close window        | Cmd+Shift+W (varies)         |         |       |          |           |       |
| Next tab            | Cmd+Shift+] / Ctrl+Tab       |         |       |          |           |       |
| Previous tab        | Cmd+Shift+[ / Ctrl+Shift+Tab |         |       |          |           |       |
| Launcher invoke     | Cmd+Space                    |         |       | n/a      |           |       |
| Autofill / password | Cmd+\ (1Password)            |         |       |          | n/a       |       |

## Open questions

- Which launcher candidate to trial first?
- Drop `programs.firefox.enable` from `hosts/hardy/default.nix` and
  `hosts/gauss/default.nix`, or is Firefox intentionally kept installed
  alongside Brave for a reason not yet recorded?

## Modifier mapping (resolved 2026-07-23)

Daniel remaps modifiers on macOS so the physical Alt key (next to Space,
matching a real MacBook's Cmd position) acts as Cmd, not the Windows-key
position. The Linux equivalent is the standard xkb option
`altwin:swap_alt_win` (ships in `xkeyboard-config`, confirmed present at
`/nix/store/czwchfqv2v6v2gm545mhdj03smk50rw0-xkeyboard-config-2.47/share/X11/xkb/symbols/altwin`):
physical Alt emits `Super_L`/`Super_R`, physical Super/Win emits `Alt_L`/`Alt_R`.
This means our existing "Super is the Cmd-equivalent modifier" decision does
not change — bindings stay `Super+key`; the swap only changes which physical
key generates that keysym, and it leaves GNOME's native Alt-based shortcuts
(Alt+Tab, etc.) untouched, since they still respond to an `Alt` keysym, just
from the other physical key now.

Applied live (mutable, not yet in the flake) via:

```sh
gsettings set org.gnome.desktop.input-sources xkb-options "['altwin:swap_alt_win']"
```

Still open: confirm whether NixOS's `services.xserver.xkb.options` actually
drives this GNOME-Wayland session's layout, or whether the durable encoding
needs to target the GNOME `input-sources` gsetting/dconf path instead (GNOME
on Wayland may source its own layout independent of the system X11 xkb
config) — verify before harvesting into `hosts/gauss/default.nix`.

## Test infrastructure (session-local, not persisted)

No key-injection or screen-capture tooling was installed on `gauss`
previously. For this session, fetched ephemerally via `nix run`/`nix build`
(not added to `flake.nix` — these are diagnostic tools, not part of the host
baseline):

- `wev` — objective keysym/modifier event logging (must have focus on its own
  window to observe events, so useful for spot-checks, not a global logger).
- `grim` — screenshot capture, for visual confirmation without needing Daniel
  to describe UI state.
- `ydotool`/`ydotoold` — synthetic input injection, so most validation doesn't
  require Daniel to physically press every candidate chord. `ydotoold` is
  running as root (`sudo ydotoold --socket-path=/tmp/.ydotool_socket
  --socket-own=1000:100`), socket owned by `daniel:users`, **not** a
  persistent systemd service — dies at reboot/logout, nothing written to
  `hosts/gauss/default.nix`. Confirmed working: `ydotool key 29:1 29:0`
  (Ctrl press/release) succeeded once the socket ownership was set to the
  numeric UID:GID (the flag takes `UID:GID`, not names).
