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
- `scripts/e2e.sh` is the public entry point.
- The script warns that the suite will take control of the visible desktop and
  uses Gum to request confirmation.
- The harness runs as Daniel from the active graphical user session.
- The default path never uses `sudo`.
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

The Bun project carries no third-party package dependencies. Use `bun:test`,
Bun's standard APIs, and small repository-owned TypeScript utilities.

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

Prefer narrow declarative permissions over runtime elevation. If a later test
unavoidably requires elevation, it must be explicitly opted into and skipped
under the default no-sudo invocation.

## Test Shape

Use ordinary `bun:test` constructs: `describe`, `test`, and lifecycle hooks. Do
not introduce a custom test runner or suite DSL during the spike.

Keep the initial layout compact:

```text
scripts/
└── e2e.sh

tests/
└── e2e/
    ├── setup.ts
    ├── desktop.ts
    ├── keyboard.ts
    └── ghostty.test.ts
```

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
- the Bun source runs with concurrency one and no third-party package
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
public entry point and ordinary `bun:test` sources under `tests/e2e/`. The rapid
loop is direct `bun test`, never a Nix build or VM boot. Keep the code compact,
strict, idiomatic TypeScript with no third-party Bun dependencies. System tools
are allowed when declaratively installed and must be asserted by global test
setup. Add Gum to the shared system packages and use it for the confirmation UX.
Tests run with concurrency one and report every invisible desktop action before
it occurs.

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
