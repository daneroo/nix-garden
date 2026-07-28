# Simplified Keybinding Model

Status: draft

## Decision

Test whether physical Alt can remain native Alt and serve as Daniel's primary
application modifier on Linux.

The durable preference is physical: the key immediately left of Space carries
Command-like application semantics. Both current hosts put Alt there. Linux does
not need to turn that key into Super merely because macOS calls the equivalent
role Command.

| Modifier | Ownership                                 |
| -------- | ----------------------------------------- |
| Alt      | Command-like application actions          |
| Super    | Desktop, workspace, and window management |
| Ctrl     | Native Unix/Linux Control behavior        |

Trial the model on `hardy` first, then verify that it generalizes to `gauss`.
Keep the existing observable desktop tests as the behavioral contract.

## Cold-Start Handoff

The goal is to preserve the tested user-visible capabilities while simplifying
how they are produced. Read [keybindings](../../docs/keybindings.md) as the
current baseline, not as an implementation to reproduce. The history below
explains why the experiment exists; it does not prescribe another remapping
layer.

Work test-first:

- Run the existing headless suite unchanged to establish the green baseline.
- Before changing a host, adapt the suite to express the target modifier
  ownership. Preserve its behavioral assertions and observation paths; change an
  expected physical chord only when ownership intentionally moves.
- Add coverage that distinguishes native Alt, Ctrl, and Super. The new tests
  must reject the current global Alt -> Super carrier rather than pass under
  both implementations.
- Make automated regression exercise `hardy` before trialing Hardy's production
  configuration. The current `test-desktop` output imports Gauss, while
  `--host hardy` is available only in unasserted exploration mode.
- Keep the suite green through the smallest Hardy change, then run the same
  contract against Gauss before calling the model shared.

Do not delete a mechanism-specific assertion merely because its mechanism is
being removed. Replace it with the intended invariant or observable outcome. The
executable plan should name the exact new cases and negative control after the
test surface has been inspected.

## Why Revisit the Current Model

The current implementation converts physical Alt to Super through keyd. Ghostty
and GNOME bind Super directly; Brave uses a focus-sensitive application mapper
to translate Super back to Ctrl.

That model was a reasonable first solution:

- Super offered a mostly collision-free namespace.
- Physical Alt still produced the desired Command-like behavior.
- The completed Gauss and Hardy work proved the required application behavior.

It also introduced machinery that may be unnecessary:

- Every primary chord crosses a global Alt -> Super transformation.
- Brave crosses a second Super -> Ctrl transformation.
- The base mapping differs between the two hosts.
- Reasoning must distinguish physical Alt, logical Super, Command equivalence,
  and the displaced hardware Meta source.

The complete running map remains in [keybindings](../../docs/keybindings.md).
The earlier tickets and Git history retain the experiments, abandoned
mechanisms, and bugs that led to the current baseline.

## Proposed Model

Leave base modifiers native:

```text
physical Alt -> Alt -> Command-like application action
physical Win/Search -> Super -> desktop action
physical Ctrl -> Ctrl -> native Control action
```

Start with the smallest common Command-like set Daniel uses:

```text
Alt+C  copy
Alt+V  paste
Alt+T  new tab
Alt+N  new window or document
Alt+W  close the current surface
Alt+Q  quit the application
```

Compare two realization strategies:

- **Default compatibility with exceptions:** translate those Alt chords to the
  native Linux Ctrl chords for ordinary GUI applications. Ghostty and the VS
  Code integrated terminal are required exceptions because Ctrl and Alt/Meta
  have distinct terminal meanings.
- **Targeted hooks:** bind native actions in Ghostty and translate only the
  applications that require compatibility. This is more explicit and remains the
  fallback if default translation makes focus or exception handling unreliable.

GNOME owns only the global actions needed before PaperWM, such as launcher,
lock, screenshot, and logout. PaperWM later receives the Super namespace for
window and workspace navigation without redefining the application modifier.

## Boundaries

- Preserve the behavior documented in `docs/keybindings.md`.
- Preserve literal Ctrl and the Alt/Meta terminal commands Daniel actually uses.
- Treat the VS Code editor and its integrated terminal as different contexts.
- Leave right Alt native unless evidence shows it is safe to consume; do not
  break AltGr.
- Keep Hardy's keyboard-illumination rules even if its base modifier swap
  disappears.
- Do not mix this behavior change with PaperWM, Home Manager, flake-parts, or a
  module-layout refactor.
- Do not solve remote image transport as part of modifier selection. Verify
  local Codex image paste separately from terminal text paste.

## Experiment

### Baseline

- Run the existing headless desktop E2E suite before changing behavior.
- Record occupied Alt chords and the literal Alt/Meta terminal commands Daniel
  needs.
- Separate assertions of user-visible behavior from assertions of the current
  Super carrier and application mapper.
- Keep SSH and Herdr recovery available throughout.

### Hardy

- Remove only the global Alt <-> Super base swap.
- Retain hardware-specific keyd rules.
- Implement the default compatibility layer and explicit terminal exceptions.
- Fall back to targeted hooks where the default layer is broader or less
  reliable.
- Re-run the Ghostty, Brave, GNOME, Vicinae, and 1Password acceptance behavior.
- Exercise text copy/paste locally, through SSH, and through Herdr.
- Check application menus, VS Code editor/terminal focus transitions, literal
  Meta commands, and stale application-mapper state.
- Verify persistence after logout/login and reboot.

### Gauss

- Apply the settled Hardy model to the conventional PC keyboard.
- Confirm native Alt remains the primary source and native Win supplies Super.
- Exercise an external keyboard and preserve right Alt/AltGr.
- Run the same automated and physical acceptance pass.

### Compare

- Count global and focus-sensitive transformations.
- Compare the remaining Hardy/Gauss configuration delta.
- Identify the small host adapter and the genuinely shared behavior.
- Defer the shared Nix module shape until the behavior is proven.

## Decision Criteria

Prefer native Alt when it:

- preserves the validated equivalence map;
- keeps terminal Ctrl and Alt/Meta behavior usable;
- makes focus-sensitive exceptions reliable;
- reduces transformations and host-specific configuration;
- leaves Super available for desktop navigation;
- passes the existing E2E suite and real-hardware checks on both hosts.

Keep the current Super carrier if native Alt creates broader or less predictable
conflicts than the extra transformation avoids.

## Open Questions

- Is default Alt -> Ctrl compatibility more reliable than targeted hooks?
- Which literal Alt/Meta terminal commands must remain available?
- Can Ghostty and VS Code terminal exceptions avoid stale focus state?
- Which application-menu conflicts matter in daily use?
- Can local Codex image paste coexist with Ghostty's Alt+V action?
- Does Hardy's simpler result transfer cleanly to Gauss and external keyboards?
