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
- Raycast-equivalent launcher — **not present in `flake.nix`**. Scope narrowed
  2026-07-23, direct from Daniel: he doesn't use most of Raycast — actual
  requirement is (1) app search, most-recently-used ordered first, (2) inline
  calculator, (3) date-math (e.g. "3 days from now"). Everything else Raycast
  offers is rarely used; do not over-scope the evaluation around a full
  extension ecosystem. GNOME Activities search is the zero-install baseline to
  beat (has app search, unclear if truly MRU-ordered; no calculator/date-math).

  Survey (background research agent, 2026-07-23): GNOME's compositor is Mutter,
  which does **not** implement `wlr-layer-shell` — this kills `wofi`, `fuzzel`,
  and `anyrun` outright (wlroots-only, dead ends here). `krunner` drags in most
  of the Plasma stack to run standalone — not worth it. Remaining candidates,
  ranked, **still need verification against the narrowed requirement above**
  (survey didn't confirm calculator/date-math per candidate):
  1. **Vicinae** — purpose-built Raycast clone (extension store, Qt/C++, not
     wlroots-bound), confirmed working on Mutter/GNOME, packaged in nixpkgs with
     a Home Manager module. Likely has calculator/date-math given it targets
     Raycast parity, but unconfirmed — check before committing to it.
  2. **Ulauncher** — mature, actively developed, runs on Mutter via a documented
     full-screen-transparent-window workaround, has a plugin ecosystem
     (calculator extension exists; date-math unconfirmed).
  3. **rofi** (plain `rofi`/xcb mode via Xwayland, **not** `rofi-wayland` — same
     wlr-layer-shell problem as wofi) — lightweight, scriptable, has a calc
     mode; loses precise overlay positioning under Xwayland.

Functions (minimum set, expand as gaps surface):

Captured 2026-07-23, Ghostty scope, from Daniel directly (priority as stated):

- Copy / paste — high priority; must also pass through cleanly inside a Herdr
  session (Daniel's tmux-like multiplexer, no muscle memory for its own bindings
  yet, but copy/paste should behave normally there too — real test case, not
  just a Ghostty-alone check). **Confirmed 2026-07-23**: attaching to the same
  live Herdr session from inside Ghostty (plain `herdr`, reattaches to the
  running server) — Super+C/V worked normally through Herdr, no interference.
- Next tab / previous tab — highest priority, used most.
- New tab / close tab — used often, lower priority than next/prev.
- Clear / clear scrollback — explicit ask (Cmd+K on macOS).
- New window / quit app — nice to have, low priority.
- Split pane / jump-to-tab-N — explicitly not needed (Herdr covers
  pane-equivalent workflows; tab-N jump is never used).
- Find, font-size zoom — not raised when asked; treat as out of scope unless a
  gap surfaces later.

Cross-app consistency principle (2026-07-23): Daniel isn't confident macOS
itself is consistent between Brave and Ghostty for next/prev tab — and
explicitly wants ours to be, regardless. Design rule: pick one canonical chord
per function and make every app match it, rather than chasing each app's
possibly-inconsistent macOS default. Locked in for next/prev tab:
`Super+Shift+]` / `Super+Shift+[`, chosen and validated for Ghostty first; Brave
must match exactly, which is a real test of whether native per-app config
suffices (Brave/Chrome tab-switching isn't normally user-remappable without an
extension or enterprise policy — first likely candidate for the remap-layer
escalation if native config can't hit this exact chord).

Still to capture: the same walk-through for Brave, the launcher, and 1Password
(switch window/app, spotlight/search, screenshot, lock screen, etc. remain open
for those apps).

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

| Function            | macOS                        | Ghostty          | Brave | Launcher | 1Password | Notes                                                      |
| ------------------- | ---------------------------- | ---------------- | ----- | -------- | --------- | ---------------------------------------------------------- |
| Copy                | Cmd+C                        | Super+C ✅       |       |          |           |                                                            |
| Paste               | Cmd+V                        | Super+V ✅       |       |          |           | GNOME conflict fixed, see below                            |
| New tab             | Cmd+T                        | Super+T ✅       |       |          |           |                                                            |
| Close tab           | Cmd+W                        | Super+W ✅       |       |          |           | `close_tab:this`                                           |
| New window          | Cmd+N                        | Super+N ✅       |       |          |           | GNOME conflict fixed, see below                            |
| Close window        | Cmd+Shift+W (varies)         | not bound        |       |          |           | Gap: distinct from close-tab; not requested, not yet bound |
| Next tab            | Cmd+Shift+] / Ctrl+Tab       | Super+Shift+] ✅ |       |          |           | Canonical chord — every app must match this exactly        |
| Previous tab        | Cmd+Shift+[ / Ctrl+Shift+Tab | Super+Shift+[ ✅ |       |          |           | Canonical chord — every app must match this exactly        |
| Clear / scrollback  | Cmd+K                        | Super+K ✅       | n/a   | n/a      | n/a       | `clear_screen`, unbound by Ghostty default                 |
| Quit app            | Cmd+Q                        | Super+Q ✅       |       |          |           |                                                            |
| Launcher invoke     | Cmd+Space                    | n/a              | n/a   |          |           |                                                            |
| Autofill / password | Cmd+\ (1Password)            | n/a              |       | n/a      |           |                                                            |

Ghostty: **9/9 validated** 2026-07-23, all via native per-app config (no remap
layer needed) — `~/.config/ghostty/config`, live/mutable, not yet in the flake.
See "Ghostty experiment results" below for the two GNOME conflicts found and
fixed along the way.

## Open questions

- Which launcher candidate to trial first?
- Drop `programs.firefox.enable` from `hosts/hardy/default.nix` and
  `hosts/gauss/default.nix`, or is Firefox intentionally kept installed
  alongside Brave for a reason not yet recorded?

## Modifier mapping (resolved 2026-07-23)

Daniel remaps modifiers on macOS so the physical Alt key (next to Space,
matching a real MacBook's Cmd position) acts as Cmd, not the Windows-key
position. The Linux equivalent is the standard xkb option `altwin:swap_alt_win`
(ships in `xkeyboard-config`, confirmed present at
`/nix/store/czwchfqv2v6v2gm545mhdj03smk50rw0-xkeyboard-config-2.47/share/X11/xkb/symbols/altwin`):
physical Alt emits `Super_L`/`Super_R`, physical Super/Win emits
`Alt_L`/`Alt_R`. This means our existing "Super is the Cmd-equivalent modifier"
decision does not change — bindings stay `Super+key`; the swap only changes
which physical key generates that keysym, and it leaves GNOME's native Alt-based
shortcuts (Alt+Tab, etc.) untouched, since they still respond to an `Alt`
keysym, just from the other physical key now.

Applied live (mutable, not yet in the flake) via:

```sh
gsettings set org.gnome.desktop.input-sources xkb-options "['altwin:swap_alt_win']"
```

Still open: confirm whether NixOS's `services.xserver.xkb.options` actually
drives this GNOME-Wayland session's layout, or whether the durable encoding
needs to target the GNOME `input-sources` gsetting/dconf path instead (GNOME on
Wayland may source its own layout independent of the system X11 xkb config) —
verify before harvesting into `hosts/gauss/default.nix`.

## Ghostty experiment results (2026-07-23)

Native per-app config (Ghostty's own `keybind` config) was sufficient for all 9
captured functions — no global remap layer (`keyd`) needed, per the
simplest-first bias. Config written to `~/.config/ghostty/config` (live,
mutable, not yet harvested into the flake):

```ini
keybind = super+c=copy_to_clipboard:mixed
keybind = super+v=paste_from_clipboard
keybind = super+t=new_tab
keybind = super+w=close_tab:this
keybind = super+shift+]=next_tab
keybind = super+shift+[=previous_tab
keybind = super+k=clear_screen
keybind = super+n=new_window
keybind = super+q=quit
```

Two failures on first pass, both **GNOME Shell global shortcuts intercepting the
chord before Ghostty ever saw it** — not a Ghostty or remap-layer problem:

- `Super+V` did nothing → `org.gnome.shell.keybindings.toggle-message-tray` was
  `['<Super>v', '<Super>m']`.
- `Super+N` did nothing →
  `org.gnome.shell.keybindings.focus-active-notification` was `['<Super>n']`.

Fixed live (mutable, reversible):

```sh
gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>m']"
gsettings set org.gnome.shell.keybindings focus-active-notification "[]"
```

Revert if ever needed:

```sh
gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>v', '<Super>m']"
gsettings set org.gnome.shell.keybindings focus-active-notification "['<Super>n']"
```

Implication for later apps: before assuming a per-app config failure means
"escalate to a remap layer," check `gsettings list-recursively` against
`org.gnome.desktop.wm.keybindings`, `org.gnome.shell.keybindings`,
`org.gnome.mutter.keybindings`, `org.gnome.mutter.wayland.keybindings`, and
`org.gnome.settings-daemon.plugins.media-keys` for the same chord first — this
was the actual cause both times so far, not app or mechanism limitations.

Debugging note: testing initially got confused because CLI invocations of
`ghostty +show-config`/`+validate-config` silently start Ghostty's
single-instance backend process in the background (`--initial-window=false`),
and separately, Daniel's actual default terminal turned out to be GNOME Console
(`kgx`), not Ghostty — the first "nothing works" report was against a Ghostty
backend with no visible window, not a real test. Confirm which terminal a test
is actually running in before trusting a negative result.

## Test infrastructure (session-local, not persisted)

No key-injection or screen-capture tooling was installed on `gauss` previously.
For this session, fetched ephemerally via `nix run`/`nix build` (not added to
`flake.nix` — these are diagnostic tools, not part of the host baseline):

- `wev` — objective keysym/modifier event logging (must have focus on its own
  window to observe events, so useful for spot-checks, not a global logger).
- `grim` — screenshot capture, for visual confirmation without needing Daniel to
  describe UI state.
- `ydotool`/`ydotoold` — synthetic input injection, so most validation doesn't
  require Daniel to physically press every candidate chord. `ydotoold` is
  running as root
  (`sudo ydotoold --socket-path=/tmp/.ydotool_socket --socket-own=1000:100`),
  socket owned by `daniel:users`, **not** a persistent systemd service — dies at
  reboot/logout, nothing written to `hosts/gauss/default.nix`. Confirmed
  working: `ydotool key 29:1 29:0` (Ctrl press/release) succeeded once the
  socket ownership was set to the numeric UID:GID (the flag takes `UID:GID`, not
  names).
