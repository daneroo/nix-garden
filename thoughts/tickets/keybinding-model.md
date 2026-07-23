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
  of the Plasma stack to run standalone — not worth it.

  **Resolved 2026-07-23** — all three remaining candidates actually trialed
  live; see "GNOME-level functions" below for the full results. **Vicinae won**
  (MRU search + calculator confirmed, no date-math though), Ulauncher kept as a
  documented lighter backup (works, simpler, not installed), rofi ruled out
  (hard-requires `wlr-layer-shell` on Wayland in v2.0.0, same dead end as
  wofi/fuzzel/anyrun under Mutter, with no override flag available).

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
  `gauss` first. **Hint for that backport** (2026-07-23, from prior-art research
  below): the `stevenilsen123/mac-keyboard-behavior-in-linux` keyd config swaps
  **Ctrl↔Meta** rather than Alt↔Super, so its "Cmd" key physically emits `Ctrl`
  — which happens to already be a common native close/shortcut modifier across
  many Linux apps, sidestepping a lot of the per-app remapping this ticket
  needed. Worth considering as an alternative base-layer strategy specifically
  for `hardy`'s constrained keyboard (missing key entirely, not just "which key
  plays which role" like gauss), not necessarily as a change to gauss's
  already-validated Alt↔Super swap.
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

## Mechanism candidates

An earlier repo review
([claude-initial-impressions-and-guidance](../reviews/claude-initial-impressions-and-guidance.md#desktop-and-keybindings))
floated these as starting hypotheses. Status as of 2026-07-23, after actually
running the experiments:

- **Per-app native config** — validated for Ghostty (9/9 functions, no remap
  layer needed). Insufficient alone for Brave (Chromium exposes no native
  shortcut settings and no remappable API reaching Super/Meta).
- **Global remap layer (`services.keyd` + `keyd-application-mapper`)** —
  validated and **in production** for Brave's tab/window functions and the base
  Alt↔Super swap (replacing the earlier xkb-only approach entirely). Required
  patching a GNOME Shell extension for an untested Shell version and fixing two
  real bugs (see "Brave experiment results") — real cost, but it worked and is
  now the actual mechanism, not a hypothesis.
- **Home Manager** — still not needed; not revisited, per the standing rule in
  `feedback_defer_home_manager` not to adopt it pre-emptively.
- **Wrapped programs**
  ([module-architecture](../research/module-architecture.md)) — still not
  relevant; no cross-platform (`galois`/macOS) portability requirement has
  surfaced.

A browser extension via `chrome.commands` was also tried for Brave and
**abandoned** — see "Brave experiment results" for why (a hard Chromium platform
limit, not a fixable bug).

## Equivalence map (fill in during research)

| Function            | macOS                        | Ghostty          | Brave                        | Launcher       | 1Password            | Notes                                                  |
| ------------------- | ---------------------------- | ---------------- | ---------------------------- | -------------- | -------------------- | ------------------------------------------------------ |
| Copy                | Cmd+C                        | Super+C ✅       | not bound via our mechanism  |                |                      | Browser default (Ctrl+C) untouched; gap, see below     |
| Paste               | Cmd+V                        | Super+V ✅       | not bound via our mechanism  |                |                      | GNOME conflict fixed, see below; same gap as Copy      |
| New tab             | Cmd+T                        | Super+T ✅       | Super+T ✅                   |                |                      | Brave via `keyd`, not the extension — see below        |
| Close tab           | Cmd+W                        | Super+W ✅       | Super+W ✅                   |                |                      | `close_tab:this`                                       |
| Reopen closed tab   | Cmd+Shift+T                  | n/a              | Super+Shift+T ✅             | n/a            | n/a                  | Brave native Ctrl+Shift+T, via `keyd`                  |
| New window          | Cmd+N                        | Super+N ✅       | Super+N ✅                   |                |                      | GNOME conflict fixed, see below                        |
| Close window        | n/a — see note               | not bound        |                              |                |                      | Not a real distinct macOS chord; see note below        |
| Next tab            | Cmd+Shift+] / Ctrl+Tab       | Super+Shift+] ✅ | Super+Shift+] ✅             |                |                      | Canonical chord, matched exactly in both apps          |
| Previous tab        | Cmd+Shift+[ / Ctrl+Shift+Tab | Super+Shift+[ ✅ | Super+Shift+[ ✅             |                |                      | Canonical chord, matched exactly in both apps          |
| Address-bar focus   | Cmd+L                        | n/a              | Ctrl+L (Brave default, kept) | n/a            | n/a                  | No extension API can do this; not achievable via Super |
| Find                | Cmd+F                        | n/a              | Ctrl+F (Brave default, kept) | n/a            | n/a                  | Same limitation as address-bar focus                   |
| Clear / scrollback  | Cmd+K                        | Super+K ✅       | n/a                          | n/a            | n/a                  | `clear_screen`, unbound by Ghostty default             |
| Quit app            | Cmd+Q                        | Super+Q ✅       |                              |                |                      |                                                        |
| Launcher invoke     | Cmd+Space                    | n/a              | n/a                          | Super+Space ✅ | n/a                  | Vicinae; MRU search + calculator confirmed, see below  |
| Autofill / password | Cmd+Shift+Space (1Password)  | n/a              | via browser extension        | n/a            | Super+Shift+Space ✅ | Matches 1Password's real macOS default exactly         |

Ghostty: **9/9 validated** 2026-07-23, all via native per-app config (no remap
layer needed), now declaratively encoded in `hosts/gauss/default.nix`. See
"Ghostty experiment results" below for the two GNOME conflicts found and fixed
along the way.

Brave: **6/6 core tab/window functions validated** 2026-07-23, all via `keyd`

- `keyd-application-mapper` — the browser-extension approach (`chrome.commands`)
  was abandoned entirely; see "Brave experiment results" below for why, and for
  two real bugs found and fixed along the way (a double-swap regression, and an
  undeclared composite layer). Copy/Paste not addressed via our mechanism —
  Brave's browser-default Ctrl+C/V still works untouched, just doesn't match the
  Super-based scheme; logged as an open gap, not urgent since it already works.

Close window (as a chord distinct from close-tab): briefly implemented as
`Super+Shift+W` (Ghostty `close_window`, Brave `Ctrl+Shift+W` via `keyd`) then
**reverted** the same session — Daniel correctly caught that Cmd+Shift+W isn't
actually a standard macOS convention (this ticket's own first draft had already
flagged it "(varies)", which got missed when implementing). The real macOS
pattern is that Cmd+W is _contextual_: it closes the current tab when multiple
tabs are open, and closes the window itself when there's only one tab left — not
a distinct chord to replicate. Nothing bound for that specific idea; revisit
only if a genuine need for a separate close-window chord surfaces, not as a
macOS-equivalence item.

Separately, plain `Super+W` **is** bound for every app other than Ghostty and
Brave (which already have their own specific handling) — a general close-window
catch-all via `keyd`, Ctrl+W output, see "Brave experiment results" below and
the `[!bc]*` section in `hosts/gauss/default.nix`'s `keydAppConf`. Best-effort
per prior-art research, not exhaustively verified against every app.

## GNOME-level functions (2026-07-23)

- **Dash pinned apps** — `org.gnome.shell.favorite-apps` set to Ghostty, Brave,
  and Files (Nautilus was already a GNOME default; Ghostty/Brave pinned by
  Daniel via the UI, then read back and encoded declaratively). Not a
  keybinding, but adjacent desktop-baseline state that surfaced during this
  work.
- **Launcher invoke (Cmd+Space)** — `<Super>space` freed from the default
  `switch-input-source` binding (kept via the dedicated `XF86Keyboard` hardware
  key instead, function not lost). Three candidates actually trialed live
  2026-07-23 against the narrowed requirement (MRU app search, inline
  calculator, date-math):
  - **Activities overview** (`toggle-overview`, the zero-install baseline) —
    tried first; has app search but no calculator/date-math, so didn't satisfy
    the requirement. Left unbound in the final config (superseded, not removed
    as a GNOME feature).
  - **rofi** (plain, not `rofi-wayland`) — hard dead end: rofi 2.0.0 refuses to
    start at all on Wayland without the layer-shell protocol
    (`Wayland-ERROR: Rofi on wayland requires support for the layer shell protocol`),
    no override flag exists, and forcing X11 via `GDK_BACKEND=x11` doesn't
    bypass its own Wayland detection. Forcing genuine X11 mode
    (`env -u WAYLAND_DISPLAY DISPLAY=:0`) got further but hit a separate,
    unrelated `XAUTHORITY` staleness (pointed at an auth file rotated away by an
    earlier logout this session) — not pursued further once a working candidate
    (Vicinae) was already in hand.
  - **Ulauncher** — actually works (confirmed via verbose log: real keyboard
    focus, rendered results, launched an app), contrary to an initial "didn't
    see it" impression — likely genuinely running but visually similar enough to
    Vicinae to cause confusion when switching between the two quickly. Simpler
    than Vicinae. **Kept as a documented lighter backup**, not installed
    declaratively — revisit if Vicinae ever becomes too heavy.
  - **Vicinae** — **won**. Confirmed live: MRU-ordered app search, inline
    calculator (own bundled "Qalculate!" backend, started automatically).
    Confirmed gaps: no date-math (none of the three candidates had it, not just
    Vicinae); clipboard history needs Vicinae's own separate GNOME extension
    (`github.com/dagimg-dot/vicinae-gnome-extension`, same class of fix as
    `keyd`'s extension, not yet pursued) — degrades gracefully to a dummy
    clipboard backend rather than failing, so this is a missing feature, not a
    broken one.

  Installed via `environment.systemPackages`; no NixOS module ships for it (only
  a Home Manager one, not adopted per `feedback_defer_home_manager`), so its
  client/server split (`vicinae server` / `vicinae toggle`) is wired by hand:
  `systemd.user.services.vicinae` (`wantedBy = graphical-session.target`) runs
  the server, and the `<Super>space` custom keybinding runs `vicinae toggle`.
  Known quirk: adding a new `wantedBy=graphical-session.target` unit while that
  target is already active (i.e. any `nixos-rebuild switch` during an existing
  session, not a fresh login) does not retroactively start it — confirmed twice
  this session; needed a manual `systemctl --user start vicinae` each time. Not
  a bug, just something to expect after every switch during iteration; a fresh
  login starts it automatically.

- **1Password Quick Access (Cmd+Shift+Space)** — matches 1Password's own actual
  macOS default shortcut exactly, not a Cmd-equivalence guess. Bound
  `<Super><Shift>space` to `1password --quick-access` (a real first-class CLI
  flag; confirmed working live). Requires the 1Password desktop app already
  running — its own single-instance IPC forwards the flag to the existing
  process. Autofill _into_ Brave itself still needs the 1Password browser
  extension, which arrives via Daniel's existing Brave sync chain — nothing to
  package or configure here.
- **Workspace switch left/right (macOS Spaces reflex, Ctrl+Left/Right)** —
  deliberately **not** bound. Plain `Ctrl+Left/Right` is the near-universal
  word-navigation shortcut in text fields; a GNOME WM-level grab intercepts
  globally before any app sees the key, so it would have broken word-nav
  everywhere for a workspace-switch win. `Ctrl+Shift+Left/Right` (word-select)
  was considered as a lower-risk alternative — no existing GNOME conflict, and
  Daniel doesn't rely on that function much (already non-functional in
  Ghostty/Herdr; works in Brave's location bar, low priority to keep) — but
  ended up unnecessary: GNOME's own **existing default** bindings,
  `Super+Alt+Left/Right` and `Ctrl+Alt+Left/Right`, already work and map cleanly
  onto Cmd+Option+Left/Right in Daniel's physical muscle-memory terms once the
  Alt↔Super swap is applied. Adopted as-is — **zero config change, zero risk**,
  not something built. If plain Ctrl+Left/Right specifically is ever wanted,
  revisit the word-nav tradeoff explicitly; don't add it casually.

## Open questions

- ~~Which launcher candidate to trial first?~~ Resolved — Vicinae, see
  "GNOME-level functions".
- ~~Drop `programs.firefox.enable`...~~ Resolved 2026-07-23: dropped from both
  `hosts/gauss/default.nix` (applied and verified) and `hosts/hardy/default.nix`
  (edited, not yet applied — needs `hardy`'s own `just apply`, out of reach from
  this `gauss` session). Confirmed genuinely unused first (not running, no real
  profile in `~/.mozilla`, only auto-created native-messaging entries from other
  apps' installers).

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

## Brave experiment results (2026-07-23)

Two mechanisms were tried in sequence. The first (a browser extension) was
built, deployed, and then **abandoned once proven fundamentally incapable of
reaching the actual goal** — not because it was hard, but because it could never
deliver a Super-based trigger no matter how well built. The second (`keyd` +
`keyd-application-mapper`) is what's actually in place now, and validated end to
end: **6/6 core tab/window functions confirmed working live** (New tab, Close
tab, Reopen closed tab, New window, Next tab, Previous tab).

### Attempt 1: browser extension via `chrome.commands` — abandoned

Brave/Chromium has no native keyboard-shortcut settings page at all (true of
every Chromium-based browser) and no policy to declaratively set an extension's
shortcut trigger — confirmed via
[Chrome's ExtensionSettings policy docs](https://chromeenterprise.google/policies/extension-settings/).
A small local extension was built anyway (`hosts/gauss/brave-macos-shortcuts/`,
`chrome.commands` + `chrome.tabs`/`chrome.windows`/`chrome.sessions` APIs,
deployed via a user-level `~/.local/share/applications/brave-browser.desktop`
XDG override with `--load-extension`, RSA-keyed for a stable extension ID) —
fully working mechanically, sanity-checked headless, extension confirmed loaded
in `brave://extensions`.

It was abandoned once Daniel actually tried assigning a trigger at
`chrome://extensions/shortcuts` and hit Chrome's hard platform limit: **every
`chrome.commands` shortcut must include Ctrl or Alt (never both together, to
avoid AltGr conflicts); Meta/Super is not accepted at all, on any platform** —
confirmed via
[Chrome's own commands documentation](https://developer.chrome.com/docs/extensions/reference/api/commands).
No amount of extension code can work around this — it's enforced before the
extension's own JS ever runs. This meant the extension could never beat Brave's
own pre-existing native Ctrl-based defaults, so it added complexity for zero
actual benefit. Since it also cost a real, ongoing UX price (the
developer-mode-extension nag banner on every Brave launch) for zero benefit, the
extension, its `--load-extension` desktop-file override, and the
`hosts/gauss/brave-macos-shortcuts/` source were all deleted once this was
confirmed dead — Git retains the history if the API constraint ever changes. Do
not resurrect this approach without new information (e.g. a future Chromium API
change).

### Attempt 2: `keyd` + `keyd-application-mapper` — what's actually running

Real fix: `keyd` remaps physical Alt↔Super below the compositor (replacing the
old xkb `altwin:swap_alt_win`, which this fully subsumes);
`keyd-application-mapper` retranslates our Super-based chords into Brave's own
native Ctrl-based ones, but **only while a Brave window has focus** — a GNOME
Shell extension feeds it live window-focus events, so Ghostty (or anything else)
keeps receiving plain Super+key when it has focus.

Validated via a nested-Niri protocol test (see "Modifier mapping" and the plan's
execution log) that this focus-detection approach is far more solid under a
wlroots compositor than on GNOME — but GNOME is the current baseline, so the
GNOME-specific path was pursued:

- nixpkgs's `keyd` (2.6.0) ships two GNOME Shell extension builds
  (`gnome-extension`, `gnome-extension-45`), declaring support only up to Shell
  45–49. This system runs **Shell 50.2** — one version newer than anything
  shipped or tested upstream.
- Patched `metadata.json` to add `"50"` to `shell-version` (via a small Nix
  derivation, `keydGnomeExtensionPatcher` + `pkgs.runCommand`, not a manual
  one-off edit) and deployed via the same `systemd.tmpfiles.rules` `L+` pattern
  used elsewhere. **Validated working** — the extension's actual logic
  (`Shell.WindowTracker.focus-app`, `Meta.Window.get_wm_class`/ `get_title`,
  `Main.layoutManager`) uses only long-stable Shell APIs and ran correctly once
  patched; GNOME Shell also wraps extension `enable()` in error handling, so a
  broken extension fails safely rather than crashing the session.
- `keyd-application-mapper` needed to be resolvable via PATH by whatever spawns
  it (the extension, via `GLib.spawn_command_line_async`) — added via
  `users.users.daniel.packages = [ pkgs.keyd ]` (the per-user profile path), not
  just the keyd service's own `ExecStart`, since already-running processes' PATH
  entries include that directory and don't need a fresh login to see new files
  placed there.
- Socket access: upstream's docs assume a dedicated `keyd` group
  (`usermod -aG keyd <user>`), which the NixOS module doesn't create. Overrode
  `systemd.services.keyd.serviceConfig.Group = "users"` (daniel's existing
  primary group) instead — avoids requiring a fresh login for group membership
  to take effect. Confirmed: socket ends up `root:users`, `rw-rw----`.
- Brave's real (normalized) window class, confirmed via `-v` verbose output:
  **`brave-browser`** (all lowercase) — used directly in `app.conf` rather than
  a defensive wildcard.
- **Note on `keyd bind` semantics, confirmed by direct testing**: runtime
  overrides set via `keyd bind <bindings>` persist in the daemon's memory
  independent of whatever process issued them — killing
  `keyd-application-mapper` does **not** clear its last-applied bindings. Don't
  infer "the mechanism is broken" from a stale binding still working after the
  process that set it is gone; restart the `keyd` service itself
  (`systemctl restart keyd`) to get a clean read during debugging.

### Two real bugs found and fixed (both root-caused, not guessed)

1. **Double-swap regression** — broke Ghostty's already-working `Super+N` after
   `keyd` was introduced. Root cause: an early manual
   `gsettings set org.gnome.desktop.input-sources xkb-options "['altwin:swap_alt_win']"`
   command (hours earlier, before `keyd` existed) wrote a **local per-user dconf
   override**. When the ticket's xkb-based swap was later replaced with `keyd`'s
   in `hosts/gauss/default.nix`, only the _system default_ was removed — the
   local override, being higher-priority, silently survived and kept applying.
   With both swaps active, physical Alt got swapped twice (once by `keyd` at the
   kernel level, once by xkb on top), cancelling back to plain `Alt` at the
   application level. Diagnosed by a clean bisection (fully stop `keyd`, confirm
   the app-level symptom persists → the active bug isn't in `keyd` at all)
   rather than more guessing, then found via
   `gsettings get org.gnome.desktop.input-sources xkb-options`. Fixed with
   `gsettings reset` (not `set` — this specifically clears the local override so
   the removed system default actually takes effect, rather than setting a new
   local value that would itself later need cleanup).
2. **Undeclared composite layer** — `meta+shift.<key>` bindings (next/prev tab,
   reopen-closed-tab) appeared to do nothing, then were found to leak literal
   `{`/`}` characters into whatever text field had focus (e.g. Brave's address
   bar) when the chord was held. Root cause, confirmed via
   `keyd bind "meta+shift.rightbrace=C-tab"` directly:
   `"meta+shift is not a valid layer"` — per `keyd(1)`, composite layers
   (`[layer1+layer2]`) must be explicitly declared in the static config before
   any dynamic `keyd bind` reference to them will resolve; an undeclared
   reference fails outright rather than falling back to anything sensible, so
   the raw Shift+bracket keystroke passed through as literal text instead. Fixed
   by declaring an empty `[meta+shift]` section in
   `services.keyd.keyboards.default.settings` (Nix attribute ordering after
   `main` satisfies the man page's "must be defined after the layers of which
   they are comprised" requirement, since Nix's `toINI` iterates `attrNames`
   alphabetically and `"main" < "meta+shift"`).

### Incidental fix along the way

`Super+L` was GNOME's global lock-screen shortcut
(`org.gnome.settings-daemon.plugins.media-keys.screensaver`), colliding with
what would have been Brave's address-bar-focus binding under the (abandoned)
extension approach. Lock-screen is a function Daniel actually wants, unlike the
message-tray/notification frees for Ghostty — moved to `Super+Shift+L` (checked
free first) rather than dropped. Stands on its own merit even though address-bar
focus itself turned out unachievable for Brave either way.

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
