# Simplified Keybinding Model

Status: active

Goal: preserve Daniel's existing physical Alt-centered shortcuts on Hardy and
Gauss while removing the global Alt-to-Super carrier and keeping Alt, Ctrl, and
the physical key that produces Linux Super distinct.

## Baseline and Boundaries

The planning baseline at `3e4e2f8` is green: `just check` passed, and the
unchanged Gauss-backed `test-desktop` suite passed all 12 assertions in 41.3
seconds. Because Galois is `aarch64-darwin`, the Linux suite ran on Hardy from
an immutable copy of the clean flake source; Hardy's checkout and running system
were not changed.

- [x] After Daniel approves this revised draft, commit it on `main`.
      `[tier: low]`
- [x] Daniel pushes the approved plan commit. In the separate Hardy execution
      session, fast-forward a clean `main` to that commit and create the exact
      branch `simplified-keybinding-model`. Do not implement on `main`.
      `[tier: low]`
- [x] At implementation start on Hardy, require a clean checkout containing the
      approved plan, then record `git status`, `git rev-parse HEAD`,
      `just current-state`, and the running generation. Rerun `just check` and
      the unchanged headless E2E suite; stop on drift or an unexplained baseline
      failure. `[tier: high]`
- [x] Treat [docs/keybindings.md](../../docs/keybindings.md) as the current
      behavioral inventory, not an implementation blueprint. Preserve the
      covered physical behavior except for the two explicitly removed Brave
      conveniences below. `[tier: high]`
- [x] Use precise Linux terminology throughout implementation: Alt, Ctrl, and,
      when relevant, the physical Search key on Hardy or Windows-logo key on
      Gauss that produces Linux Super. Do not use macOS modifier names or "Meta"
      as active key terminology. `[tier: high]`
- [x] Keep PaperWM, Home Manager, flake-parts, module extraction/refactoring,
      home-config ownership, unrelated keyd security work, VS Code behavior, and
      Codex image paste out of scope. The two independent host profiles may
      duplicate the proven behavior until module architecture is addressed
      separately. `[tier: high]`
- [x] Treat maintainability as an acceptance constraint. If an automated
      consequence requires private internals, pixel matching, extensive timing,
      or a new general-purpose harness, stop and present Daniel with the
      evidence, cost, and recommendation to waive or defer it. Do not escalate
      test complexity merely because a case was named in this plan.
      `[tier: high]`

## Target Physical Contract

- [ ] Keep physical Alt as the primary shortcut modifier and bind it directly.
      Keep physical Ctrl native. Leave the physical Search/Windows-logo key
      native as Linux Super, restore ordinary GNOME Super defaults where the old
      carrier was the only reason for overriding them, and do not move any
      covered Alt action onto Super. `[tier: high]`
- [ ] Require left Alt as the primary physical path. Do not specially remap
      right Alt; application toolkits may treat both Alt keys alike under the US
      layout. Preserve AltGr on keyboards/layouts that provide it.
      `[tier: high]`
- [x] Preserve this Ghostty map with direct Alt bindings: Alt+C/V/T/W/N,
      Alt+Shift+]/Alt+Shift+[, Alt+K, and Alt+Q. Alt+Q remains declarative but
      is not exercised in the normal behavioral sequence because it destroys
      fixture state. Alt+D is the representative unbound terminal Alt chord;
      Ctrl+C is the representative native terminal Control chord. `[tier: med]`
- [x] Use Hardy's fuller Brave map as the converged target: Alt+C/V/T/W/N/L/F,
      Alt+Shift+T, and Alt+Shift+]/Alt+Shift+[. Remove Hardy's redundant,
      destructive Alt+Shift+W convenience, leave Alt+Q unmapped, and remove
      Gauss's best-effort catch-all for unnamed applications. `[tier: high]`
- [x] Translate Alt only in named applications that require it. Ghostty binds
      Alt directly; Brave may retain its focused keyd application mapper and
      patched GNOME Shell focus extension, translating selected native Alt
      chords to Brave's native Ctrl chords. Do not add a broad default
      Alt-to-Ctrl compatibility layer. Revisit that decision only if future
      named applications create substantial repeated configuration.
      `[tier: high]`
- [ ] Converge both hosts on this physical desktop map: Alt+Space for Vicinae;
      Alt+Shift+Space for 1Password Quick Access; Alt+Shift+L and the preserved
      Ctrl+Alt+Q fallback for lock; Alt+Shift+3/4 for screenshots; Alt+Shift+Q
      for the logout confirmation dialog; native Alt+Tab for application
      switching; and Alt+Search/Windows-logo+Left/Right for workspaces. Preserve
      Print Screen fallbacks. `[tier: high]`
- [x] Give Vicinae ownership of native Alt+Space by explicitly clearing GNOME's
      conflicting active-window-menu binding. For any other stock GNOME
      collision, the covered Alt chord wins, the displaced binding is
      documented, and no replacement chord is invented unless it is required for
      recovery or Daniel demonstrates that he uses it. `[tier: high]`
- [x] Keep Hardy's observed internal-keyboard ID only for hardware-specific
      Alt+F6/F7 keyboard illumination. Modifier ownership is not
      device-specific. External keyboards receive no Chromebook illumination
      rule. `[tier: med]`

## Test Contract First

- [x] Parameterize the existing desktop test with the smallest public change:
      publish Hardy and Gauss instances of the same contract, accept
      `--host hardy|gauss` in headless and visible assertion modes, and retain
      the existing `test-desktop` output as a compatibility alias. Bare
      `just e2e-vm` selects the current blessed NixOS host; an explicit host
      selects the other configuration. Galois is a coordinator, not a NixOS test
      executor. `[tier: med]`
- [x] Add a test-only GTK/GDK probe that records the relevant logical modifier
      mask after QEMU injects physical left Alt, left Ctrl, and the physical key
      that produces Super. Assert exact, distinct Alt-only, Ctrl-only, and
      Super-only results. Do not infer modifier identity from successful
      injection or process state. `[tier: med]`
- [x] Add a narrow declarative invariant that neither host contains the old base
      Alt-to-Super mapping. This complements the behavioral probe because QEMU's
      Virtio keyboard cannot match Hardy's real internal-keyboard ID.
      `[tier: med]`
- [x] Before production changes, run the new modifier contract against unchanged
      Gauss and record its expected red result: physical Alt arrives as Super
      under the carrier. Observe test-first red results without committing a
      deliberately broken checkpoint. `[tier: high]`
- [x] Retain the keyd application-map delivery, patched extension, and mapper
      process checks as cheap supplemental diagnostics because the target still
      uses them for Brave. They are preconditions, never proof of Brave
      behavior. Replace their former acceptance role with observed or explicitly
      guided application consequences. `[tier: med]`
- [x] Extend the Ghostty protocol fixture and its semantic observations:
      preserve copy, paste, tab creation/closure/selection, window creation, and
      tab navigation; assert that Ctrl+C reaches the PTY as Control-C; and
      assert that Alt+D reaches the PTY as an unbound terminal Alt sequence.
      Keep every shared-state precondition explicit. `[tier: med]`
- [x] Keep a declarative assertion for Ghostty Alt+K, then populate the fixture,
      inject Alt+K, and pause four seconds as a guided clear-screen case near
      the end of the Ghostty sequence. Do not semantically claim that
      inaccessible terminal cells were observed. `[tier: med]`
- [x] Add a deterministic local Brave fixture. Keep a cheap declarative
      assertion for the complete intended chord table, then seek stable semantic
      observations for each consequence family: clipboard, tab
      creation/closure/reopen/navigation, window creation, address focus, and
      find. Prefer clipboard contents, active document/title, tab/window counts,
      and accessibility state. `[tier: med]`
- [x] When a Brave consequence lacks a maintainable semantic boundary, retain
      automated setup, focus, chord injection, and a four-second guided pause.
      Run the same action and pause in headless and `--show` modes, place guided
      cases after asserted state, and allow them to appear as passing subtests
      without claiming their consequence was asserted. `[tier: med]`
- [x] Inject Alt+Shift+L identically in headless and visible modes, assert the
      exact native Alt+Shift+L event sequence, pause four seconds for guided
      lock observation, then send the fixture password and restore the unlocked
      session. The visible VM requires confirmation of the lock consequence;
      headless GNOME ignored the correctly emitted accelerator, so it must not
      claim a semantic lock assertion. For Alt+Shift+Q, assert the session
      precondition, use the same four-second guided observation, send Escape,
      and assert that the session survived; never confirm logout inside the
      shared regression VM. `[tier: med]`
- [x] Preserve Alt+Shift+3, Alt+Shift+4, and Print Screen fallbacks
      declaratively. The planned headless Alt+Shift+3 file assertion is waived:
      both its unchanged Shift+Print positive control and the target chord
      failed to produce file evidence in the headless VM, while the Screenshot
      app and Hardy's carrier-era physical chord produced screenshots in
      visible/real sessions. GNOME Shell 50 also restricts its screenshot D-Bus
      methods to MediaKeys and the desktop portal, so a direct test-process
      invocation is not a valid substitute. Require the target physical chord to
      create a new file on real Hardy after apply. `[tier: med]`
- [x] Keep Vicinae and 1Password out of VM automation. Their required physical
      checks need the real session; the VM has no authenticated Brave or
      1Password state. `[tier: med]`
- [ ] Use Files as the sole required stock-GNOME negative control on real
      hardware: native Ctrl behavior must remain, and Files must not inherit the
      targeted Alt translation. Do not expand the matrix to Clocks, Weather, or
      Settings. `[tier: low]`

## Hardy Experiment

- [x] Remove Hardy's Alt/Super base swap while retaining its internal-keyboard
      device scope for illumination. Physical Alt remains Alt, Ctrl remains
      Ctrl, Search remains Super, internal Alt+F6/F7 still emits keyboard
      illumination events, and external keyboards remain native. `[tier: med]`
- [x] Bind Ghostty and the covered GNOME actions directly to native Alt. Restore
      carrier-era GNOME Super defaults that no longer collide, clear the native
      Alt+Space window menu for Vicinae, and retain the established physical
      fallbacks. `[tier: med]`
- [x] Change Brave's focused source chords from the old carrier to native Alt.
      Keep the focused mapper and Shell extension only where required for the
      complete Brave map. Complete, reliable Brave behavior is a hard acceptance
      requirement; do not close with missing chords or replace the carrier with
      another broad transformation. `[tier: high]`
- [x] Run `just check`, the headless Hardy suite, and the identical visible
      Hardy suite before the first apply. Daniel must observe and confirm all
      guided cases. Require Hardy green; the same target contract may remain
      deliberately red on unchanged Gauss during this intermediate branch
      milestone. Both Hardy runs passed 27/27. Daniel observed the Ghostty and
      Brave guided consequences and accepted the four-second lock/logout
      injections without visual confirmation as sufficient for this pre-apply
      gate. `[tier: high]`
- [ ] Commit and push the Hardy milestone before planning it. Run `just plan` on
      Hardy, review the closure diff, session/re-login implications, affected
      keyd and dconf state, and rollback generation with Daniel, then wait for
      explicit approval before `just apply`. The recipe's own confirmation is an
      additional guard, not the approval. `[tier: high]`
- [ ] Keep Galois SSH and Herdr recovery available through the switch. If
      modifier identity, Ctrl behavior, keyboard access, GNOME login, or remote
      recovery becomes unreliable, roll back immediately to the recorded
      generation. If Hardy remains operable and only a noncritical chord fails,
      preserve evidence and diagnose in place. Any fix must be declarative,
      committed, pushed, re-planned, and separately approved; do not repair with
      persistent runtime keyd overrides. `[tier: high]`
- [ ] Reconcile after apply: run `just current-state`, compare
      `/run/current-system` with the planned result, inspect keyd and GNOME user
      units, confirm effective dconf values and store-backed files, remove only
      identified stale runtime/local overrides, and rerun the Hardy headless
      suite. Record switch warnings separately from actual verification.
      `[tier: high]`
- [ ] On Hardy's internal keyboard, verify Alt, Ctrl, and physical Search
      independently; the complete Ghostty and Brave maps; Vicinae open/dismiss;
      1Password Quick Access and a Brave extension-to-desktop smoke check;
      lock/unlock; logout confirmation/cancel; Alt+Shift+3; native Alt+Tab;
      Alt+Search+Left/Right; and Alt+F6/F7 keyboard illumination. Prefer Alt+W
      for normal closure; confirm only that the preserved Ghostty Alt+Q remains
      declared. `[tier: high]`
- [ ] Attach an external keyboard to Hardy and repeat Alt, Ctrl, the physical
      Windows-logo key, covered application chords, right Alt/AltGr where
      available, and workspace switching. Confirm that external Alt+F6/F7 is not
      captured by the Chromebook illumination rule. `[tier: high]`
- [ ] In Files, verify representative native Ctrl behavior and confirm that the
      focused application did not inherit Brave's Alt translation. `[tier: med]`
- [ ] Log out and back in, reconcile, and repeat representative modifier,
      Brave-focus, Vicinae, and lock checks. Reboot only after the logged-in
      pass is sound; reconcile and repeat representative checks after reboot.
      `[tier: high]`
- [ ] Require Daniel to complete at least one normal Hardy work session after
      reboot, switching ordinarily among Ghostty, Brave, Vicinae, and GNOME
      applications. Daniel's real-use confirmation is the gate to Gauss
      portability; no arbitrary multi-day soak is required. `[tier: high]`

## Gauss Portability

- [ ] Only after Hardy is accepted, run the identical target suite against
      unchanged Gauss and record the expected carrier-negative failure. Port the
      settled behavior without copying Hardy's hardware illumination adapter or
      refactoring the hosts into a shared module. `[tier: high]`
- [ ] Remove Gauss's all-keyboards Alt/Super swap and unnamed-application Alt+W
      catch-all. Keep Alt, Ctrl, both Windows-logo keys, and right Alt/AltGr
      native; apply the converged Ghostty, fuller Brave, GNOME, and desktop
      chord maps. Preserve unrelated Gauss behavior. `[tier: med]`
- [ ] Run `just check`, the headless Gauss suite, and the identical visible
      Gauss suite. Daniel must observe and confirm the guided cases. Require
      both Hardy and Gauss target suites green before the Gauss milestone is
      committed. `[tier: high]`
- [ ] Commit and push the Gauss milestone before planning it. Coordinate this
      phase from Galois, which has the required SSH authority, but execute
      checkout, test, `just plan`, and approved `just apply` commands on Gauss
      itself. Do not assume Hardy can reach Gauss. `[tier: high]`
- [ ] Review Gauss's closure diff, session/re-login implications, and rollback
      generation with Daniel; wait for a separate explicit approval before
      Gauss's `just apply`. Apply the same recovery and post-apply
      reconciliation policy used for Hardy. `[tier: high]`
- [ ] On Gauss hardware, verify the complete shared application and desktop map,
      native Alt/Ctrl/Windows-logo identity, right Alt/AltGr, Files as the
      negative control, 1Password's manual checks, logout/login, reboot
      persistence, and representative behavior on an external keyboard.
      Real-hardware Gauss verification is mandatory for completion.
      `[tier: high]`

## Compare and Close Out

- [ ] Compare Hardy and Gauss by observable behavior, the absence of a global
      carrier, focused transformations that remain, exception reliability, and
      the genuine hardware-specific delta. Keep the native-Alt model only if it
      preserves the shared target and Brave remains reliable; otherwise restore
      the recorded carrier generation and document why the experiment was
      rejected. `[tier: high]`
- [ ] Run the final Hardy and Gauss suites and `just check`. Run a final
      `just plan` on each host and distinguish functional configuration drift
      from revision-only drift introduced by closeout documentation. Record
      revision-only drift without extra applies; Daniel will reconcile from
      `main` after merge outside this plan. Any functional diff still requires
      the normal committed, pushed, host-specific approval boundary.
      `[tier: high]`
- [ ] Rewrite current behavior in `docs/keybindings.md` using precise Linux
      terminology. Retain a concise preamble explaining the macOS lineage and
      physical motivation, plus a brief historical note that the former design
      carried physical Alt through Super for compatibility. Let Git preserve
      detailed obsolete mechanics. `[tier: med]`
- [ ] Harvest settled test commands, semantic versus guided evidence, fidelity
      limits, displaced GNOME bindings, device scoping, debugging facts, and
      recovery results into `docs/e2e-testing.md` and other existing durable
      pages only where useful. Update the backlog outcome, mark this plan
      `done`, and remove the superseded design after harvesting. `[tier: med]`
- [ ] Present the final physical behavior matrix, automated/guided/manual
      evidence, waivers, unresolved gaps, branch commits, and running
      generations for review. Stop with the verified feature branch; the
      coordinator owns merge, post-merge `main` planning/applying,
      completed-plan disposition, and branch cleanup. `[tier: high]`
