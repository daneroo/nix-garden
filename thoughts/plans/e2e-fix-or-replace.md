# E2E Bun Replacement Spike

Status: done

Goal: extend the proven Bun harness across the highest-value desktop chords
without changing its working input, observation, or cleanup foundation.

- [x] Record the live Gauss baseline without changing it: graphical-session
      environment, GNOME and PaperWM state, available Bun/system tools, input
      devices, keyd permissions and monitor behavior, Wayland/D-Bus/AT-SPI
      interfaces, and Ghostty process/window/focus identities. Compare physical
      input candidates by fidelity, declarative packaging, narrow no-sudo
      permissions, safety, and likely VM reuse; reject any mechanism that cannot
      be proven to enter before keyd. Evidence: commands and conclusions in the
      ticket. `[tier: high]`
- [x] Choose the smallest reliable fixture contract and physical injection path.
      Prove an injected neutral chord appears in `keyd monitor` and reaches a
      controlled observer with the expected logical modifiers before claiming
      the `Alt+N` path. If no safe no-sudo monitor path exists, require explicit
      attended sudo; never silently substitute an after-keyd mechanism.
      `[tier: high]`
- [x] Establish `tests/e2e/` as the language-neutral suite boundary and
      `tests/e2e/bun/` as the Bun project root, with a private, dependency-free
      runtime, a private `package.json`, strict `tsconfig.json`, and a lockfile
      pinning only first-party Bun type declarations. The manifest owns the
      canonical source-test command; the public script enters the project
      explicitly. Evidence: the command resolves only this source tree and the
      Nix-supplied TypeScript compiler checks it against Bun's official types.
      `[tier: low]`
- [x] Add Gum and the chosen input tool declaratively at the shared host
      boundary. Add `scripts/e2e.sh` as the public entry point: explain visible
      desktop control, request Gum confirmation and attended sudo authorization
      for direct keyd evidence, validate that it is running as Daniel in the
      active graphical session, and invoke the manifest's `bun test` command
      with concurrency fixed at one. Evidence: refusal/cancel paths and the
      guarded invocation behave as described. `[tier: med]`
- [x] Add compact, strict, runtime-dependency-free `bun:test` sources under
      `tests/e2e/bun/`. Global setup must check commands and usable graphical,
      D-Bus, Wayland, keyd-monitor, injection, GNOME, desktop-mode, and
      observation capabilities. Repository-owned helpers cover command
      execution, bounded retry, exact-output waits, readiness, GNOME state,
      typed physical chords, and actionable failures while keeping successful
      polling quiet. Evidence: capability failures identify the missing access
      or state. `[tier: med]`
- [x] Implement one independently repeatable test: launch and focus a uniquely
      identified fixture-owned Ghostty window, start keyd evidence capture,
      announce and inject physical `Alt+N`, semantically observe exactly one new
      fixture-owned window and its focus, and retain the monitor evidence.
      Manipulate no unverified pre-existing window. `[tier: high]`
- [x] Restore the relevant baseline in lifecycle cleanup on success or failure.
      Preserve the original test failure when cleanup also fails; report cleanup
      actions, residual fixture identities, and any state that may remain.
      `[tier: high]`
- [x] Exercise the rapid loop directly from source and record elapsed time:
      capability preflight, cancellation, at least one passing repeated `Alt+N`
      run, and one controlled failure demonstrating actionable output. Run
      `just check` after edits and `just plan` for the non-destructive
      build/diff. Do not run `just apply`, update inputs, switch the system, or
      require a VM. `[tier: high]`
- [x] Inventory the old Python suite's remaining behavioral actions, fixtures,
      and observation mechanisms with likely Bun replacements and blockers.
      Assess the spike's speed, clarity, input fidelity, reliability, and
      extension cost in the ticket, then pause at the feasibility gate.
      `[tier: med]`
- [x] Extend the proven fixture scenario with physical `Alt+W`: close only the
      newly created fixture window, observe focus return to the initial fixture,
      retain keyd evidence, and reuse the existing cleanup path. Evidence: two
      consecutive direct-source passes without new infrastructure. `[tier: low]`

## Ordered Replacement Extension

The passing ydotool, direct-sudo keyd monitor, AT-SPI window observer, Ghostty
fixture identity, baseline focus, and cleanup paths are frozen. Each group below
gets one targeted TypeScript check, at most two live runs, one final
`just check`, and one commit. A local assertion mistake may receive one
correction; any need for a new unplanned mechanism stops that group for review.
Do not cross group boundaries during a failure.

- [x] **Group 1 — existing Ghostty lifecycle:** append physical `Alt+Q` to the
      existing fixture sequence, semantically observe that only the isolated
      fixture application exits, retain keyd evidence, and confirm baseline
      focus. Add no helper, permission, service, package, or observer.
      `[tier: low]`
- [x] **Group 2 — one richer Ghostty terminal fixture:** add only the monotonic
      surface titles and PTY acknowledgements already proven by the old fixture.
      In one independently repeatable scenario, cover `Alt+T` tab creation,
      `Alt+Shift+[`/`]` selection, and `Alt+W` selected-tab closure. Then reuse
      that same fixture for native `Ctrl+C` and unbound `Alt+D` pass-through.
      Stop if top-level semantic titles cannot distinguish the selected surface;
      do not add a new accessibility or window mechanism. `[tier: med]`
- [x] **Group 3 — clipboard boundary:** add one baseline/restore helper for the
      user's clipboard, then cover Ghostty `Alt+C` and `Alt+V` together using
      the Group 2 fixture acknowledgements. Restoration must run on success or
      failure; do not proceed if the prior clipboard cannot be preserved.
      `[tier: med]`
- [x] **Group 4 — isolated Brave lifecycle:** add one Bun-served local page, one
      disposable Brave profile, DevTools page counts, and existing AT-SPI frame
      observation. First prove focused-app translation with `Alt+N` open and
      `Alt+W` close. Only after that passes, extend the same fixture with
      `Alt+T`, `Alt+L`, and `Alt+Shift+[`/`]`. Cover `Alt+C`/`Alt+V` without an
      external clipboard client disturbing keyd's application context. Commit
      lifecycle, navigation, and clipboard as separate subgroups. `[tier: high]`

Deferred beyond these ordered groups: automatic PaperWM mode switching, a
dedicated workspace, custom presentation, canonical Nix packaging of the Bun
project, non-GNOME/macOS invocation, complete behavioral parity, a sibling Go
implementation, VM invocation of the same suite, deletion of the Python
behavioral implementation, Brave `Alt+Shift+T`, attended GNOME globals, and
every guided action without a semantic observer.

No subagent assignment is planned: the risky work is one coupled live-session
state transition, and parallel ownership would weaken the fixture and cleanup
boundary.
