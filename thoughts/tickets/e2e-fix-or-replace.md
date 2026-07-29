# E2E: Replace with Bun

## Outcome

Prove that the desktop keyboard-binding E2E suite can be replaced with a small,
maintainable Bun test harness that runs directly in Gauss's deployed graphical
session.

The replacement direction is chosen. Do not repair or extend the Python
behavioral suite. Keep it temporarily as working evidence and as an inventory of
useful mechanisms while the Bun replacement proves its feasibility.

This ticket begins as a spike. If the vertical slice is fast, reliable, and
pleasant to extend, continue the replacement under this same ticket rather than
starting another one.

## Why Replace It

The current suite eventually passed all 27 cases on both hosts, but it is not a
fit development or regression boundary:

- every behavioral run depends on booting a VM;
- a run takes roughly 80--90 seconds even with cached build inputs;
- the NixOS test driver embeds the behavior in Python;
- shared mutable desktop state makes failures costly to diagnose;
- several guided cases perform actions without proving their consequences;
- reusable command, retry, focus, window, and desktop-state operations are
  trapped inside the VM-specific driver.

The objective is modest regression evidence for keyboard bindings that already
work, not a general desktop-automation platform.

## Primary Execution Contract

- The first execution target is Gauss's currently deployed desktop.
- `tests/e2e/` is the language-neutral suite boundary. The Bun project root is
  `tests/e2e/bun/`; its private manifest, lockfile, and strict project settings
  live beside the test sources. This gives a later Nix derivation a narrow
  source boundary and leaves room for a sibling implementation such as
  `tests/e2e/go/` without relocating Bun.
- `scripts/e2e.sh` is the public entry point.
- The script warns that the suite will take control of the visible desktop and
  uses Gum to request confirmation.
- The harness runs as Daniel from the active graphical user session.
- After explicit confirmation, the script obtains attended sudo authorization so
  the test can run the deployed keyd binary's monitor command directly.
- Tests run with concurrency fixed at one.
- The rapid development loop is direct source execution through `bun test`; it
  never requires a Nix build or a VM.
- The initial spike uses Gauss's current workspace and current PaperWM mode. It
  does not switch modes or create a dedicated test workspace.

The suite may open and focus controlled windows, inject keys, and temporarily
change visible desktop state. It records the relevant baseline, manipulates only
fixture-owned state, and makes a best-effort cleanup on success or failure.
Cleanup failures must not hide the original failure and must report any state
that may remain.

Tests that require user attention or instructed recovery may later run through
an explicit attended mode. The lock-screen case belongs in that category: assert
the lock transition, instruct Daniel to unlock normally, and continue only after
the session returns. Do not store or inject live credentials.

## Dependency Boundary

The Bun project carries no third-party runtime package dependencies. Use
`bun:test`, Bun's standard APIs, and small repository-owned TypeScript
utilities. The first-party `@types/bun` package is the only development
dependency; pin it in the Bun lockfile and use nixpkgs's TypeScript compiler
rather than maintaining local ambient declarations for Bun APIs.

System executables are allowed and should be installed declaratively when they
are the clearest mechanism. Add Gum to the shared system packages for invocation
UX; this may also include an input-injection tool. Global test setup must:

- check required executables with `command -v`;
- prove required access rather than assuming that executable presence implies
  usable permissions;
- validate the graphical session, user D-Bus, Wayland access, and input path;
- fail when an applicable required capability is absent;
- skip with an explicit reason when a test does not apply to the detected
  platform or desktop mode.

Prefer narrow declarative permissions over runtime elevation. For this spike,
Daniel explicitly selected attended sudo for direct keyd monitor evidence after
the declarative monitor service proved disproportionate. The guarded entry point
obtains authorization only after confirmation; ydotool injection remains
unprivileged.

## Test Shape

Use ordinary `bun:test` constructs: `describe`, `test`, and lifecycle hooks. Do
not introduce a custom test runner or suite DSL during the spike.

Keep the initial layout compact:

```text
scripts/
└── e2e.sh

tests/
└── e2e/
    └── bun/
        ├── .gitignore
        ├── bun.lock
        ├── package.json
        ├── tsconfig.json
        ├── setup.ts
        ├── desktop.ts
        ├── keyboard.ts
        └── ghostty.test.ts
```

The project manifest owns the canonical source-test command. Its lockfile pins
the first-party Bun type declarations; it has no runtime dependencies.
`scripts/e2e.sh` enters the project explicitly. A later Nix package should be
added to the repository's existing flake rather than making the Bun project a
nested flake.

If another implementation is justified, add it as a sibling beneath `tests/e2e/`
and let the repository flake package each implementation independently. Keep
`scripts/e2e.sh` as the stable guarded interface. Hoist fixtures to a
language-neutral location only when demonstrated sharing warrants it.

Split files or directories only as demonstrated reuse or readability demands.
TypeScript should be strict, idiomatic, and explicit about capability, key, and
desktop-state types without turning those types into a framework.

Shared requirements may be asserted once in a suite setup. Tests should remain
readable behavioral descriptions, with reusable mechanics outside the test body.
Physical keys use typed names rather than parsed chord strings.

Each top-level test must be independently repeatable. A stateful sequence such
as create, navigate, and close may remain steps within one test rather than
becoming order-dependent tests. Reassert only the local assumptions required to
make the result meaningful: controlled fixture identity, focus, active
workspace, and relevant baseline state. Do not attempt to prove that the entire
desktop is pristine.

## Reporting

`bun:test` owns the test result and summary. Add only a small action-step helper
unless experience proves the runner inadequate.

The suite must never leave the user wondering what invisible action is in
progress:

- announce every injected chord before pressing it;
- announce focus, window, workspace, and session changes before acting;
- identify the state being awaited;
- report completion and elapsed time;
- report cleanup actions;
- keep successful low-level polling and command output quiet;
- reveal the relevant command, output, attempts, and last observed state on
  failure.

OpenTUI or another custom presentation layer is an optional later replacement
for the runner, not spike infrastructure.

## Behavioral Boundary

The new suite tests behavioral keyboard outcomes. The former suite's
configuration-health checks were weak stand-ins for behavior and are not
replacement targets.

Configuration inspection is allowed only as a necessary precondition or as
diagnostic evidence after a behavioral failure. A passing declaration is never a
substitute for observing the shortcut's consequence.

Application tests use fixture-owned windows, profiles, titles, and identities
while exercising the deployed production bindings and keyd configuration. Never
type into, close, or otherwise manipulate an unverified pre-existing personal
window.

Desktop mode is detected and reported. A behavior with the same expectation
under PaperWM and standard GNOME uses one mode-agnostic test. Only genuinely
different expectations gain conditional exclusion or mode-specific assertions.

## Input Fidelity

The normal E2E path injects physical keys before keyd, like a real keyboard:

```text
physical injection -> keyd -> GNOME/focused application -> observed result
```

The spike must demonstrate that keyd sees and processes the injected chord. Do
not accept an apparent application response as proof that the production input
path was exercised.

An exceptional after-keyd input mechanism may be useful for a narrower test, but
its naming must make the reduced boundary obvious. Never silently fall back to
it, and never use it to claim that a keyd mapping was tested.

The injection mechanism and its permissions are intentionally unresolved until
they can be inspected and exercised on Gauss. Candidate mechanisms should be
judged by fidelity, simplicity, safety, existing platform support, and whether
the same approach can run inside the VM.

## Feasibility Spike

The first vertical slice is:

```text
controlled Ghostty window has focus
  -> inject physical Alt+N before keyd
  -> a new fixture-owned Ghostty window exists
  -> the new window has focus
  -> clean up fixture-owned state
```

The spike is successful when:

- `scripts/e2e.sh` provides the guarded public invocation;
- the Bun source runs with concurrency one and no third-party runtime
  dependencies;
- global setup validates commands, the graphical session, D-Bus, Wayland,
  permissions, and required desktop capabilities;
- reusable equivalents exist for the transferable responsibilities in
  `tests/lib.py`: command execution, bounded retry, exact-output waiting,
  session readiness, GNOME state, physical chord injection, and actionable
  failure reporting;
- physical injection is proven to traverse keyd;
- the `Alt+N` Ghostty outcome and focus are semantically observed;
- visible progress describes every meaningful action and wait;
- the relevant baseline is restored on a best-effort basis;
- the remaining Python actions, fixtures, and observation mechanisms are
  inventoried with blockers and likely Bun replacements.

Stop at this gate long enough to assess speed, clarity, fidelity, and extension
cost. Do not make complete behavioral parity a prerequisite for learning whether
the approach works.

## Spike Evidence

### Final feasibility result

On 2026-07-29 the direct source test passed twice consecutively on Gauss in
PaperWM mode:

- run one: scenario 0.91 seconds, one test passed;
- run two: scenario 0.93 seconds, one test passed;
- direct sudo `keyd monitor -t` attached to the ydotool virtual keyboard and
  retained `leftalt down` and `n down`;
- ydotool injected before keyd;
- exactly one second fixture-owned Ghostty window appeared;
- the new window held active focus;
- both fixture windows were removed and the original baseline focus was restored
  after each run.

The spike therefore has a practical passing vertical slice. This does not
override Daniel's assessment below about the excessive cost of reaching it or
imply that the branch should land without review.

The first bounded post-gate extension reused the same scenario for physical
`Alt+W`. On two consecutive runs, keyd retained `leftalt down` and `w down`, the
new fixture window closed, focus returned to the initial fixture window, and
full cleanup succeeded. Scenario times were 1.15 and 1.18 seconds. No new
permission, injection, observation, fixture, or cleanup mechanism was added.

With PaperWM disabled, the existing fixture lifecycle then added physical
`Alt+Q`. Two consecutive standard-GNOME runs retained `leftalt down` and
`q down`, quit only the isolated fixture application, restored baseline focus,
and completed cleanup in 1.07 seconds. This group added no helper, permission,
service, package, or observer.

The richer Ghostty terminal fixture added per-surface OSC titles and raw PTY
acknowledgements without changing the desktop mechanisms. Its first bounded run
reached tab creation and previous-tab selection but used the wrong expected keyd
names for brackets. After the one allowed local correction from
`leftbrace`/`rightbrace` to literal `[`/`]`, the second and final run passed in
1.69 seconds. It covered `Alt+T`, `Alt+Shift+[`/`]`, selected-tab `Alt+W`,
native `Ctrl+C`, unbound `Alt+D`, and the existing window lifecycle, with keyd
evidence and complete cleanup on standard GNOME.

The clipboard group added `wl-clipboard` declaratively after Daniel approved the
system change, and the activation diff contained only that package. The first
live run proved `Alt+C` but timed out because the forked `wl-copy` owner
inherited captured output pipes; Bun's timeout prevented the cleanup path from
restoring the pre-run clipboard. The original text was intentionally never
logged and could not be reconstructed. The residual fixture unit and runtime
directory were removed directly. After the one local pipe-handling correction,
the second and final run passed in 2.05 seconds on standard GNOME: `Alt+C`
copied the selected `COPY_PROBE`, `Alt+V` delivered `PASTE_PROBE` to the fixture
PTY, keyd retained both physical chords, and fixture, focus, and the captured
run baseline were restored.

Daniel's first public-script regression then stopped safely during preflight:
the clipboard contained only text but advertised the standard `UTF8_STRING`,
`STRING`, and `TEXT` aliases that the narrow MIME allowlist rejected. Accepting
those aliases made the same scenario pass in 2.07 seconds with exact baseline
restoration. That verification exposed the baseline value in the generic
exact-output progress message, so clipboard verification now reports only exit,
timeout, and equality state; clipboard contents remain redacted.

### Owner assessment

Daniel considers the current result unacceptable. The LLM switched to a direct
sudo method only after spending excessive time and tokens on permission
machinery without producing one passing behavioral assertion. Treat the direct
method as a provisional expedient to review later with a more capable LLM that
may find an obvious solution to the permission problem.

Do not assume this ticket should land. Codex may exhaust the available token
limits before completing the simplest part of the spike. Before resuming,
evaluate another LLM and agent harness for this work.

### Attempt ledger

This ledger preserves receipts for the work and discarded approaches. None of
the failed runs counts as a passing behavioral assertion.

1. The Bun package was initially treated as if the repository root were its
   project root. After Daniel objected, it moved to `tests/e2e/`, then to the
   correct language-specific root at `tests/e2e/bun/`, leaving room for a future
   `tests/e2e/go/`.
2. A handwritten `tests/e2e/bun/runtime.d.ts` ambient shim was created to avoid
   package dependencies. Daniel objected. It was deleted and replaced with a
   pinned official `@types/bun` development dependency and `bun.lock`.
3. Read-only investigation covered the graphical session, PaperWM, input-device
   ownership, `/dev/uinput`, keyd, Ghostty, GNOME D-Bus, AT-SPI, ydotool,
   dotool, and wtype. Direct AT-SPI calls were selected for window identity and
   focus observation; ydotool was selected for pre-keyd injection.
4. A declarative ydotool daemon and a bounded keyd-monitor system service were
   designed. The first monitor design ran as root and contained an ownership
   flaw discovered during generated-unit review. It was replaced before
   deployment with a Daniel-owned service carrying service-only `input`
   membership, a private evidence file, a polkit start/stop rule, and extensive
   systemd hardening.
5. Several `just check` and `just plan` cycles built and audited these designs.
   Generated units were inspected with `systemd-analyze verify` and
   `systemd-analyze security`. This work produced no key assertion.
6. The first guarded `scripts/e2e.sh` attempt stalled while Gum queried terminal
   capabilities through the remote PTY. Interrupting it produced a safe
   cancellation before desktop control. It was rerun by sending confirmation
   directly through the PTY.
7. Live run one failed before launching Ghostty because `ghostty +list-keybinds`
   does not accept `--config-file`. Cleanup also tried to restore focus even
   though fixture focus had never changed, and Ghostty rejected AT-SPI
   `GrabFocus`.
8. The binding inspection was changed to read the deployed configuration, and
   cleanup gained lifecycle guards. Live run two launched and removed the
   fixture but failed because the test still called Ghostty's unsupported
   `GrabFocus`.
9. Focus setup changed to semantically observe the focus PaperWM already gives a
   newly launched fixture. Cleanup first accepted GNOME's automatic return to
   the baseline. Live run three reached the visible outcome: physical `Alt+N`
   created exactly one second fixture window, the new window became active, and
   cleanup removed both fixture windows and restored the baseline. The test
   still failed because its separate keyd-monitor evidence file contained
   device-open failures, so the outcome was not accepted as a passing assertion.
10. The monitor service's device ACL was changed from read-only to read-write
    after inspecting locked keyd source and finding that monitor mode opens
    event devices with `O_RDWR`. The system was rebuilt and switched again.
11. More live diagnostics followed instead of stopping: process credentials and
    generated units were inspected; an already-exited process briefly produced a
    misleading root/zombie reading; the locked keyd source was searched; and
    disposable one-second systemd probes tested direct event-device open, keyd
    under the base identity, `ProtectSystem`, the syscall filter, the full
    hardening set, and an empty capability set. One probe first used the wrong
    keyd path and was repeated. Another was interrupted by an accidental Escape
    and repeated. These probes showed the hardened identity could open the
    devices and exposed a stale preserved evidence-file race.
12. A semantic readiness change was drafted to wait for keyd's fresh
    `device added` line. Before proving it, Daniel challenged the uncontrolled
    scope and the live work stopped. No fixture or monitor remained.
13. When Daniel said to use sudo directly, Codex instead drafted another
    overengineered design: an immutable timeout wrapper, a permanent sudoers
    rule, and a streamed monitor abstraction. It was typechecked but never
    applied. Daniel objected, and the wrapper and sudoers rule were removed.
14. The practical direct design then made `scripts/e2e.sh` run `sudo -v` after
    confirmation. Bun resolves the running keyd binary and directly launches
    `sudo -n <keyd-binary> monitor -t`, capturing its output in memory. The old
    monitor service, evidence file, device ACL, and polkit rule were removed
    from the desired configuration, and Gauss was switched again.
15. The first direct-sudo live run failed during preflight because Daniel cannot
    read the root keyd process's `/proc/<pid>/exe` link under the host's process
    visibility policy. Resolving that one link with the already-authorized sudo
    was implemented and passed `just check`.
16. Daniel explicitly directed completion. The corrected direct-sudo test then
    passed twice consecutively, including pre-keyd monitor evidence, the Ghostty
    window/focus outcome, and complete cleanup.
17. The first clipboard run timed out after proving `Alt+C`. `wl-copy` forked
    normally, but its clipboard-owning child inherited stdout and stderr pipes
    that the helper was waiting to drain. The forced timeout bypassed cleanup,
    leaving the fixture unit and `PASTE_PROBE` clipboard state. The exact unit
    and runtime directory were removed directly. Because clipboard contents were
    deliberately not logged, the pre-run text could not be recovered. Ignoring
    the unused inherited pipes fixed the helper without changing the mechanism;
    the second and final bounded run passed and restored its captured baseline.
18. The committed public script rejected a restorable text clipboard because
    `wl-copy` also advertised standard text aliases. The expanded text-only
    allowlist passed the full live scenario. Its restoration progress then
    revealed that the generic exact-output reporter printed the clipboard
    payload; the clipboard helper was narrowed to retain only redacted
    match/exit/timeout diagnostics.

Current state:

- the Bun Alt+N behavioral test has passed twice consecutively;
- the bounded Alt+W extension has also passed twice consecutively;
- the bounded Alt+Q extension has passed twice consecutively on standard GNOME;
- the grouped Ghostty tab and PTY extension passed within its two-run budget;
- the grouped Ghostty clipboard extension passed within its two-run budget;
- no E2E fixture or monitor process remains;
- Gauss currently has Gum, ydotool, wl-clipboard, and the rootless ydotoold
  configuration activated;
- the obsolete keyd-monitor service and polkit grant have been removed from the
  running system;
- the direct-sudo implementation exists in the uncommitted feature branch and is
  behaviorally proven on the live Gauss PaperWM session;
- the ticket's older pre-deployment evidence below is historical and partly
  superseded by this ledger.

### Live Gauss baseline

Read-only inspection established the following before implementation:

- Gauss runs Daniel's active local Wayland session. The invoking Herdr terminal
  does not carry `XDG_SESSION_ID`, so the harness resolves the one active,
  non-remote Daniel Wayland session through `loginctl` rather than trusting that
  variable.
- The deployed tools are Bun 1.3.13, Ghostty 1.3.1, and keyd 2.6.0. Gum and the
  candidate injection tools are absent until the proposed system closure is
  activated.
- PaperWM is enabled and Daniel confirmed that the current desktop is in PaperWM
  mode. `gnome-extensions list --active` is not a trustworthy runtime oracle in
  this session, so the spike records the enabled PaperWM extension as its mode
  and does not switch it.
- `/dev/uinput` is writable by `uinput`; physical event devices are readable by
  `input`; Daniel belongs to neither group. An ordinary `keyd monitor -t`
  therefore cannot open the physical devices. The proposed configuration gives
  those groups only to two fixed, sandboxed services, not to Daniel's login.
- A direct AT-SPI connection obtained from `org.a11y.Bus.GetAddress` works with
  `busctl`. Ghostty exposes its application ID, top-level window title,
  identity, active state, and `Component.GrabFocus`. GNOME Shell's window
  introspection interface denies this caller, so AT-SPI is the semantic
  observer.
- A fixture can use a separate Ghostty class, `org.nixgarden.e2e.Ghostty`, with
  single-instance behavior disabled, a random title, and a transient user unit.
  This isolates its windows without touching the existing personal Ghostty
  process.

The input candidates resolved as follows:

| Candidate | keyd boundary                                                          | Permission and packaging result                                                                                                                                  |
| --------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ydotool` | Before keyd: its persistent virtual uinput keyboard is matched by keyd | Chosen. nixpkgs provides the client, daemon, and NixOS module. A Daniel-owned mode-0600 socket exposes only injection, while the daemon alone receives `uinput`. |
| `dotool`  | Before keyd through a uinput keyboard                                  | Rejected for the spike because the caller itself needs broad `/dev/uinput` access or another repository-owned broker.                                            |
| `wtype`   | After keyd, through the Wayland virtual-keyboard protocol              | Rejected because it cannot prove the production keyd mapping.                                                                                                    |

`keyd monitor -t` observes keyd's event stream while the daemon is running. A
bounded monitor service with private evidence and an exact polkit grant was
built and audited, then discarded in favor of the direct attended-sudo command
recorded above.

The initial pre-deployment source loop was 0.03 seconds. It stopped before
fixture creation, focus, monitoring, or injection with the direct error
`required executable is unavailable: gum`. Strict compilation against the locked
official Bun declarations, `just check`, and the non-destructive `just plan`
passed at that point. This historical pre-deployment result was superseded by
the two live passing runs above.

### Remaining Python behavioral inventory

The configuration-health assertions are not migration targets: declared
bindings, store-backed dotfiles, extension/process presence, and inspection of
keyd application-map text remain ordinary configuration checks if they are worth
keeping.

| Existing behavior or mechanism                                      | Likely replacement                                                        | Constraint                                                                                                                                                                         |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Driver command, retry, exact-output, readiness, and failure helpers | `desktop.ts` command and bounded-wait helpers plus capability setup       | Implemented for the slice.                                                                                                                                                         |
| QEMU physical keyboard injection                                    | ydotool virtual keyboard plus retained `keyd monitor` evidence            | Implemented but requires activation and the live proof. The VM can continue using its virtio keyboard through a thin bridge.                                                       |
| Dogtail top-level frame names                                       | Direct AT-SPI calls through `busctl`                                      | Implemented for Ghostty window identity and focus; also suitable for Brave frames.                                                                                                 |
| Ghostty PTY title fixture                                           | Bun terminal-protocol fixture using OSC titles and a fixture class        | Implemented for tab selection, paste, Control-C, and unbound Alt; clear-screen remains deferred.                                                                                   |
| Clipboard copy/paste                                                | `wl-copy`/`wl-paste` plus fixture titles                                  | Implemented with a plain-text-only baseline guard and cleanup restoration.                                                                                                         |
| Logical Alt/Ctrl/Super mask probe                                   | A small packaged semantic key-event observer                              | AT-SPI cannot expose raw modifier masks. Reusing Python GI would defeat the replacement boundary; a later language-neutral helper or sibling Go implementation is a plausible fit. |
| Lock and unlock                                                     | ScreenSaver D-Bus state plus explicit attended recovery                   | Never inject a live credential.                                                                                                                                                    |
| Brave local pages, tabs, and windows                                | Bun HTTP fixture, isolated profile, DevTools page list, and AT-SPI frames | Straightforward, but profile/process/clipboard cleanup must become independently repeatable.                                                                                       |
| Clear-screen, browser find, and logout dialog guided checks         | Attended mode unless a stable semantic observer is found                  | GNOME exposes no stable public logout-modal property; do not replace these with pixel or timing assertions.                                                                        |

## VM Replacement and Python Deletion

The stretch goal is to invoke the same Bun suite inside the existing NixOS VM.
The guest may receive the Bun sources, fixtures, required system tools, and
permissions through its test configuration.

A minimal Python bridge may remain because the NixOS test framework uses Python
to boot and control the VM. Its only responsibilities should be:

- start the VM;
- wait for the graphical session;
- invoke the Bun suite as the logged-in guest user;
- return the suite's output and exit status.

Delete the Python behavioral tests and helpers when the VM runs the same Bun
implementation. No keyboard scenario, polling rule, fixture behavior, window
assertion, or application knowledge should remain in Python.

## Deliberately Deferred

Name these parts in the spike plan, but do not design them in detail before the
vertical slice provides evidence:

- breadth of the final regression set;
- automatic PaperWM enable/disable testing;
- a dedicated fixture workspace;
- attended-mode complexity beyond the first real need;
- custom runner or OpenTUI presentation;
- canonical Nix packaging of the Bun application;
- invocation from macOS or another non-GNOME host;
- complete migration of every existing behavioral case.

## Gauss Handoff Prompt

Use this prompt to continue the ticket from Gauss's deployed graphical session:

```text
Continue nix-garden ticket `e2e-fix-or-replace` on Gauss.

Work from the canonical checkout at `/home/daniel/nix-garden`. Read `AGENTS.md`,
`docs/workflow.md`, `docs/workspace.md`, and
`thoughts/tickets/e2e-fix-or-replace.md` completely before acting. Inspect the
current Git state and reconcile it with the ticket; do not assume this chat's
context.

We have completed discussion and accepted the ticket. Before implementation,
write a concise executable plan at
`thoughts/plans/e2e-fix-or-replace.md` on `main`. Plan only through the defined
feasibility-spike gates in detail. Name the larger deferred parts without
prematurely decomposing them. Include checkboxes, acceptance evidence,
verification, delegation tiers, and any bounded subagent assignments that
actually help. Commit the ticket and plan on `main`, then create the exact branch
`e2e-fix-or-replace` with no prefix.

The spike target is the live Gauss desktop. Use `scripts/e2e.sh` as the guarded
public entry point and ordinary `bun:test` sources under `tests/e2e/bun/`. The
rapid loop is direct `bun test`, never a Nix build or VM boot. Keep the code
compact, strict, idiomatic TypeScript with no third-party runtime dependencies.
Keep the Bun project root and its private manifest, lockfile, and strict settings
under `tests/e2e/bun/`; pin the official Bun type declarations. System tools are
allowed when declaratively installed and must be asserted by global test setup.
Add Gum to the shared system packages and use it for the confirmation UX. Tests
run with concurrency one and report every invisible desktop action before it
occurs.

First investigate Gauss read-only to establish facts instead of asking Daniel:

- available input injection mechanisms and packages;
- whether candidate injection enters before keyd;
- how `keyd monitor` can prove the injected physical chord traversed keyd;
- narrow permissions needed without default sudo;
- existing GNOME, D-Bus, Wayland, AT-SPI, window, focus, and process interfaces;
- the simplest reliable fixture-owned Ghostty identity and focus boundary.

Then implement only the first vertical slice:

controlled fixture-owned Ghostty window focused
  -> inject physical Alt+N before keyd
  -> observe a new fixture-owned Ghostty window
  -> prove the new window has focus
  -> best-effort cleanup and baseline restoration

Run as Daniel from the active graphical session on the current workspace and
current PaperWM mode. Do not manipulate unverified personal windows. Preserve
the original failure if cleanup also fails and report any residual fixture
state. Use normal Bun tests, lifecycle hooks, and a minimal semantic step
reporter; do not build a custom runner, DSL, TUI, workspace manager, or broad
desktop automation framework.

The old Python suite remains reference evidence. Do not port configuration
health assertions. Stop at the spike gate and report speed, clarity, fidelity,
blockers, and likely extension cost. If the result is good, extend this same
ticket rather than creating another. The stretch goal is the same Bun suite
inside the NixOS VM with Python reduced to a minimal VM lifecycle bridge.

Follow repository safety policy: run `just check` after edits; `just plan` is
allowed for non-destructive verification; do not run `just apply`, update
inputs, switch the live system, or make other deployment changes without
Daniel's explicit request.
```
