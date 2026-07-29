# E2E Bun Replacement Spike

Status: done

Goal: prove a small Bun harness can exercise Gauss's deployed Ghostty `Alt+N`
binding through keyd and restore its fixture-owned desktop state.

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

Deferred beyond the gate: final regression breadth, automatic PaperWM mode
switching, a dedicated workspace, attended-mode recovery, custom presentation,
canonical Nix packaging of the Bun project, non-GNOME/macOS invocation, complete
behavioral parity, a possible sibling Go implementation, VM invocation of the
same suite, and deletion of the Python behavioral implementation.

No subagent assignment is planned: the risky work is one coupled live-session
state transition, and parallel ownership would weaken the fixture and cleanup
boundary.
