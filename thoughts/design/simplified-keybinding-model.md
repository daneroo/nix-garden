# Simplified Keybinding Model

Status: draft

## Decision

Determine whether the physical key beside Space can remain native Alt and serve
as Daniel's primary application modifier on Linux, replacing the current
physical Alt -> Super carrier model with fewer transformations and a larger
shared configuration across `gauss` and `hardy`.

This revisits the implementation chosen by the completed `keybinding-model` and
`hardy-keybinding-backport` work without invalidating their evidence. Those
efforts established the required behavior and exposed the distinction this
design now examines.

## Insight

Three concepts have been treated as though they were the same:

1. The physical key beside Space.
2. Its role as the primary application modifier.
3. The modifier event emitted to Linux applications.

Daniel's durable preference is physical and ergonomic: the key beside Space is
the primary application modifier.

With a PC-layout keyboard on macOS, that requires swapping Option and Command so
physical Alt produces Command. On Linux, the same physical key already produces
Alt. The current NixOS configuration converts it to Super because Super was
chosen as the Linux carrier for the Cmd-equivalent role. Hardy's successful
adaptation showed that the physical role matters more than the carrier and
raised the possibility that the Linux conversion is unnecessary.

The candidate simplification is therefore:

| Semantic role         | Physical invariant or source rule | Linux role |
| --------------------- | --------------------------------- | ---------- |
| Native Control        | Leftmost bottom-row Ctrl          | Ctrl       |
| Primary modifier      | Alt immediately left of Space     | Alt        |
| Supplemental modifier | One or more host-selected keys    | Super      |

The cross-platform invariant would be the physical primary-modifier position,
not one universal logical modifier:

- macOS: physical Alt -> Command because macOS applications use Command.
- Linux: physical Alt -> Alt, with scoped application translations only where
  Linux applications require another native modifier.

## Three-layer model

Describe and compare every binding through three explicit layers:

```text
physical layout -> semantic normalization ("magic middle")
                -> targeted functional hook
```

| Layer           | Question                                                                                                        | Expected ownership                                    |
| --------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Physical layout | Which keys exist, where are they, and what events do they emit?                                                 | Host/layout-specific facts                            |
| Magic middle    | Which physical sources activate Control, Primary, and Supplemental, and which Linux modifier carries each role? | Small normalization model                             |
| Functional hook | What should a semantic chord do in this specific context?                                                       | Mostly shared intent, context-specific implementation |

Right-side equivalents exist on some keyboards. Record that they are outside the
initial model; do not design or discuss their behavior until the left-side model
is settled.

### Layer 1: physical layout

The physical layer contains no application behavior and does not call a key
Command, Option, Primary, or Supplemental. It records hardware topology and raw
events.

Two physical anchors are stable on both current hosts:

| Physical anchor               | `gauss` / standard PC | `hardy` / C436 |
| ----------------------------- | --------------------- | -------------- |
| Leftmost bottom-row key       | Ctrl                  | Ctrl           |
| Key immediately left of Space | Alt                   | Alt            |

The standard PC layout inserts a Win key between those stable anchors. Hardy
does not; its second key left of Space is Ctrl. Hardy instead has a Search key
at the Caps Lock position.

Relevant physical sources:

| Host/layout           | Ctrl source              | Alt source        | Other available sources     |
| --------------------- | ------------------------ | ----------------- | --------------------------- |
| `gauss` / standard PC | Leftmost bottom-row Ctrl | Alt left of Space | Win and Caps                |
| `hardy` / C436        | Leftmost bottom-row Ctrl | Alt left of Space | Search at the Caps position |

Win and Search are not physically equivalent. They happen to emit the same
`KEY_LEFTMETA` event on the current hardware. Caps on a standard PC emits Caps
Lock unless explicitly remapped.

### Layer 2: the magic middle

The middle maps one or more physical source keys into semantic modifier roles.
It permits aliases: a role does not require a one-to-one relationship with a
physical key.

```text
physical source set -> semantic role -> Linux carrier
```

The semantic roles are:

| Role         | Meaning                                                         |
| ------------ | --------------------------------------------------------------- |
| Control      | Native Control behavior                                         |
| Primary      | Daniel's main application-command modifier                      |
| Supplemental | Additional modifier for optional system or Option-like behavior |

The physical-to-role source model under consideration is:

```text
Gauss:
  { Ctrl }                  -> Control
  { Alt }                   -> Primary
  { Win }, { Caps },
    or { Win, Caps }        -> Supplemental

Hardy:
  { Ctrl }                  -> Control
  { Alt }                   -> Primary
  { Search }                -> Supplemental
```

The current and proposed models differ primarily in the carrier chosen after
normalization:

| Role         | Current Super-carrier model | Candidate native-Alt model |
| ------------ | --------------------------- | -------------------------- |
| Control      | Ctrl                        | Ctrl                       |
| Primary      | Super                       | Alt                        |
| Supplemental | Alt                         | Super                      |

This is the “magic” boundary: host-specific key identities disappear, and
downstream behavior reasons about roles. The implementation may use native
events, keyd layers, or generated configuration, but those mechanisms must not
erase the semantic distinction.

### Layer 3: targeted functional hooks

A functional hook realizes one semantic chord in one binding context. The
desired function is shared; the native implementation may differ by application.

For example:

```text
Primary+V -> Paste

Ghostty: local paste_from_clipboard action
Brave:   contextual translation to native Ctrl+V
GNOME:   no application paste hook
SSH:     receives pasted text bytes, not the Primary+V chord
```

Other contexts include:

- GNOME global and window-manager bindings.
- Ghostty native actions.
- Brave focus-sensitive translations to Chromium's native Ctrl bindings.
- Vicinae and 1Password command invocation.
- Terminal-local clipboard behavior.
- Literal terminal input passed through to shells, editors, TUIs, SSH, and
  Herdr.

An end-to-end trace makes the comparison precise:

```text
Current Brave paste:
Gauss physical Alt -> Primary -> Super -> Brave hook -> Ctrl+V -> Paste

Candidate Brave paste:
Gauss physical Alt -> Primary -> Alt -> Brave hook -> Ctrl+V -> Paste

Candidate Ghostty paste:
Gauss physical Alt -> Primary -> Alt
  -> Ghostty hook -> paste_from_clipboard -> terminal text bytes
```

The physical layer and target function remain stable while the middle changes.
That isolation is what lets the experiment determine whether the current Super
carrier is useful machinery or an unnecessary transformation.

## Goals

- Preserve the validated macOS-equivalent physical chords on both hosts.
- Reduce global modifier transformations and their failure modes.
- Increase the amount of genuinely shared Nix between `gauss` and `hardy`.
- Preserve native Ctrl.
- Keep Super available for optional desktop functions without making daily
  application behavior depend on it.
- Preserve text copy/paste through local terminals, SSH, and Herdr.
- State image-input behavior explicitly rather than conflating it with terminal
  text paste.
- Measure simplification by transformations, conflicts, host deltas, and
  behavior—not only by lines of Nix.

## Non-goals

- Do not change the validated bindings while this design is exploratory.
- Do not assume fewer lines automatically means a better model.
- Do not generalize a shared module until both hosts validate the chosen
  behavior.
- Do not require every Linux application to implement a universal quit or close
  convention where none exists.
- Do not solve rich clipboard or image transport over SSH as a side effect of
  modifier selection.

## Current Super-carrier model

Both hosts currently make physical Alt the primary modifier by converting it to
Super below the compositor with keyd. Ghostty and GNOME then bind Super
directly. Brave requires another contextual translation to its native Ctrl
shortcuts.

Representative paths:

```text
Ghostty:
physical Alt -> keyd Super -> Ghostty Super binding -> action

Brave:
physical Alt -> keyd Super -> keyd application mapper Ctrl -> Brave action

GNOME:
physical Alt -> keyd Super -> GNOME Super binding -> action
```

The secondary mapping differs in its physical source:

| Host    | Primary source -> current role | Supplemental source -> current role | Scope                  |
| ------- | ------------------------------ | ----------------------------------- | ---------------------- |
| `gauss` | Alt -> Super                   | Win -> Alt                          | all attached keyboards |
| `hardy` | Alt -> Super                   | Search -> Alt                       | internal keyboard only |

Hardy's Search key emits left Meta/Super even though the keyboard has no
bottom-row Win key. Its second key left of Space is the leftmost bottom-row
Ctrl; Search occupies the Caps Lock position. The current mapping converts
Search to Alt/Option. Hardy also uses keyd for its keyboard-illumination chords,
so simplifying the modifier model would not necessarily remove keyd from that
host.

### What the current model buys

- Super is a mostly collision-free application-command namespace.
- Existing Linux Alt menu accelerators and terminal Meta bindings remain
  available through the normalized supplemental source.
- The physical primary key behaves consistently across the validated apps.

### What the current model costs

- Every primary chord crosses a global keyd transformation.
- Brave crosses a second transformation from Super to Ctrl.
- The base keyboard mapping is host-specific even though the intended primary
  role is shared.
- Super generally does not traverse a terminal or SSH connection as a useful
  modifier event.
- The hardware Meta source is repurposed as Alt rather than remaining an
  ordinary optional system modifier.
- Reasoning and documentation must distinguish physical Alt, logical Super,
  Cmd-equivalence, host-specific supplemental sources, and the remapped Option
  role.

## Candidate models

### A. Current Super carrier

Retain the validated implementation and improve only code sharing.

```text
physical Alt -> Super -> app action
physical Alt -> Super -> scoped Ctrl translation -> native app action
```

This remains the baseline because its behavior is proven and Super provides a
clean namespace.

### B. Native Alt as the primary modifier

Leave the keyboard's base modifiers native and bind the primary behavior to Alt.

```text
physical Alt -> Alt -> app action
physical Alt -> Alt -> scoped Ctrl translation -> native app action
```

Expected shape:

- Ghostty binds Alt+C/V/T/W/K/N/Q and tab navigation directly.
- Brave's focus-sensitive mapper translates selected Alt chords to its native
  Ctrl commands.
- GNOME binds launcher, 1Password, screenshots, lock, and logout directly to
  Alt-based chords.
- Native Alt+Tab already supplies the desired application switch.
- Alt+Space is reassigned from GNOME's window menu to Vicinae.
- The host's configured supplemental sources normalize to Super for optional
  system actions. Gauss may use Win, Caps, or both; Hardy uses Search.
- Hardy retains only hardware-specific keyd behavior such as keyboard
  illumination and exact device scoping.

This candidate removes the global modifier carrier but not necessarily the Brave
application mapper or its GNOME extension.

### C. Ctrl-first control

Map the physical primary position to Ctrl and rely on native Linux application
shortcuts.

```text
physical primary key -> Ctrl -> native app action
```

This may minimize per-application configuration, but it collapses the primary
role into native Control, sacrifices a distinct modifier, and changes terminal
semantics substantially. It is a comparison control, not the leading proposal.

## Preliminary comparison

| Dimension                     | Super carrier                      | Native Alt                         |
| ----------------------------- | ---------------------------------- | ---------------------------------- |
| Global primary-key remap      | Required                           | None                               |
| Brave translation             | Super -> Ctrl                      | Alt -> Ctrl                        |
| Ghostty binding namespace     | Super                              | Alt                                |
| GNOME binding namespace       | Mostly collision-free              | Existing Alt conflicts to resolve  |
| Native Ctrl                   | Preserved                          | Preserved                          |
| Native Alt/Meta               | Moved to supplemental role         | Used as primary namespace          |
| Super                         | Consumed as primary carrier        | Normalized supplemental role       |
| Terminal/SSH modifier support | Super is generally unavailable     | Alt/Meta is normally representable |
| Host-specific layout mapping  | Gauss and Hardy variants           | Small source-set adapters          |
| keyd requirement              | Base mapping plus app mapper       | App mapper; Hardy hardware rules   |
| Conceptual transformations    | Up to two before native app action | Up to one before native app action |

The native-Alt model is simpler only if its conflicts and displaced Meta
functions remain smaller than the machinery it removes.

## Terminal and clipboard boundary

### Text copy and paste

Terminal clipboard actions are normally local terminal-emulator operations. The
shortcut itself should not reach the remote process.

```text
Alt+V
  -> Ghostty reads the local text clipboard
  -> Ghostty writes text into the terminal input stream
  -> SSH or Herdr transports those bytes
  -> the remote shell or Codex receives pasted text
```

Likewise, terminal copy places locally selected terminal text into the local
clipboard; the remote application does not need to receive Alt+C.

Intercepting Alt+C/V therefore affects a remote application only when that
application intentionally assigns a distinct command to literal Meta-C or
Meta-V. Emacs `M-v` is a representative conflict. The design must test the Meta
commands Daniel actually uses rather than treating all intercepted Alt chords as
remote-paste failures.

### Images

Image input is not ordinary terminal text paste. Current Codex documentation
says its interactive composer can accept pasted images and that files can be
attached explicitly with `-i` or `--image`. Herdr documents streaming terminal
input and rendered ANSI frames over SSH, but does not document rich clipboard or
image upload.

Relevant references:

- [Codex image inputs](https://learn.chatgpt.com/docs/image-inputs)
- [Herdr remote operation](https://github.com/ogulcancelik/herdr#from-anywhere)

A bitmap in Galois's clipboard must not be assumed to cross into Codex running
on Hardy merely because text paste works. If Codex's interactive image paste
depends on receiving its own key event and reading the clipboard of the machine
where Codex runs, a Ghostty-local paste binding may also change that behavior.

The design must distinguish and test:

| Codex location       | Input           | Expected transport                             |
| -------------------- | --------------- | ---------------------------------------------- |
| Local                | Text clipboard  | Ghostty text paste                             |
| Remote via SSH/Herdr | Text clipboard  | Ghostty -> terminal bytes                      |
| Local                | Image clipboard | Codex interactive image-paste handling         |
| Remote via SSH/Herdr | Image clipboard | Explicit bridge or file transfer may be needed |

`codex -i <remote-path>` is the explicit fallback after transferring an image
file to the machine where Codex runs.

## Known native-Alt conflicts

- Alt+Tab is already the desired GNOME application switch.
- Alt+Space normally opens GNOME's window menu and must be reassigned for
  Vicinae.
- Alt+F commonly activates an application or browser menu and conflicts with
  Find.
- Applications may expose other Alt menu accelerators.
- Shells, editors, and TUIs use Alt as Meta for word movement, paging, and
  application-specific commands.
- Binding Alt+C/V/T/W in Ghostty reserves those chords locally while Ghostty has
  focus.
- External keyboards may distinguish right Alt/AltGr; a universal rule must not
  erase that distinction without evidence.

These are reasons to test native Alt, not reasons to reject it in advance.

## Complexity measures

Compare candidates using the following evidence:

1. **Transformation count:** modifier changes between the physical event and the
   native application action.
2. **Global interception:** rules affecting every application or keyboard.
3. **Contextual interception:** focus-sensitive rules and their failure modes.
4. **Host delta:** configuration that differs between `gauss` and `hardy`.
5. **Shared behavior:** configuration that can be identical and validated on
   both.
6. **Conflict count:** displaced GNOME, application-menu, terminal, and TUI
   shortcuts.
7. **Coverage:** results against the complete equivalence table in
   `docs/keybindings.md`.
8. **Transparency:** literal Ctrl, Alt/Meta, and Super behavior locally and
   through SSH/Herdr.
9. **Recovery:** ability to disable a failed mapper without losing keyboard or
   remote control.
10. **Explanation cost:** how many physical/logical layers a user or maintainer
    must understand.

Raw Nix line count is supporting evidence, not the decision by itself.

## Experiment

Use a fresh branch and an executable plan only after this design is vetted.
Gauss is the preferred first trial because it has a conventional PC keyboard;
Hardy then tests whether the result actually generalizes.

### Capture the baseline

- Preserve the current validated equivalence table as the behavioral baseline.
- Record effective GNOME and application bindings that occupy candidate Alt
  chords.
- Identify the Alt/Meta terminal commands Daniel uses in practice.
- Record the physical source sets for native Control, primary, and supplemental
  roles on each host.
- Record behavior for both left and right Alt and for an external keyboard.

### Trial native Alt

- Remove only the global Alt <-> Super base swap on the trial host.
- Change Ghostty's primary bindings from Super to Alt.
- Change Brave's contextual source bindings from Meta/Super to Alt while keeping
  native Ctrl targets.
- Rebind GNOME functions to the physical Alt chords.
- Normalize the chosen supplemental sources to Super. On Gauss, compare Win,
  Caps, and both aliases; on Hardy, retain Search as the source.
- Keep SSH recovery and keyd's emergency termination path available.

### Validate behavior

- Re-run every row of the existing Ghostty, Brave, GNOME, Vicinae, and 1Password
  acceptance map.
- Test Alt+Tab, Alt+Space, Alt+F, application menus, workspace navigation, and
  any retained Super functions.
- Test every configured supplemental source and confirm that multiple aliases
  produce the same shared behavior.
- Test local shell and Codex text copy/paste.
- Test text copy/paste through plain SSH and Herdr.
- Test representative literal Meta commands such as word movement and paging.
- Test local Codex image paste separately from remote image attachment.
- Test an external keyboard without assuming its right Alt key is
  interchangeable with left Alt.
- Log out and reboot before accepting persistence.

### Compare implementation shape

- Count global and contextual transformations in both models.
- Diff the Gauss and Hardy keybinding configuration after the same behavior is
  validated.
- Separate the small host layout adapters from shared role-based behavior and
  identify which remaining differences are truly hardware-specific.
- Sketch a shared Nix boundary only after the experiment proves it.

## Decision criteria

Prefer native Alt when all of the following are true:

- It preserves the physical primary-modifier behavior that matters to Daniel.
- It matches or improves the current equivalence-table coverage.
- Lost Alt/Meta functions are unused, replaceable, or smaller than the removed
  global remapping machinery.
- Text workflows remain reliable locally and through SSH/Herdr.
- Image-input behavior is understood and has an explicit local and remote path.
- The resulting Gauss and Hardy configurations share more behavior with fewer
  transformation layers.
- Super can remain optional rather than becoming a hidden dependency.

Retain the Super carrier if native Alt creates broader or less predictable
conflicts than the global swap avoids. A clean synthetic namespace may justify
the extra transformation.

## Potential shared boundary

If native Alt wins, a later implementation may share:

- The semantic primary and supplemental role definitions.
- Ghostty's primary bindings.
- Brave's contextual Alt -> Ctrl map.
- Patched keyd application-mapper extension wiring.
- Vicinae and 1Password bindings.
- GNOME screenshot, lock, logout, and switching bindings.
- The acceptance map and verification procedure.

Host-specific configuration should then be limited to demonstrated hardware
facts, including:

- The physical source set assigned to each semantic role.
- Hardy's internal-keyboard device ID.
- Hardy's keyboard-illumination events and persistence.
- External-keyboard exceptions such as AltGr.
- Any genuinely different GNOME or hardware behavior.

The exact module layout is deferred until behavior is proven; this design
chooses the abstraction before choosing a Nix abstraction.

## Open questions

- Which literal Alt/Meta terminal commands does Daniel use enough to preserve?
- Does native Alt interfere with any indispensable application-menu behavior?
- Can local Codex image paste coexist with a Ghostty-local primary paste
  binding?
- What explicit workflow should move image files into remote Codex sessions?
- Should right Alt remain native or be excluded to preserve AltGr?
- Should Gauss assign Win, Caps, or both as aliases for the supplemental role?
- If Caps becomes supplemental on Gauss, is Caps Lock intentionally retired,
  moved, or available through a secondary action?
- Which GNOME Super functions remain useful when Vicinae and Alt+Tab cover the
  common navigation paths?
- Does the native-Alt model eliminate enough host-specific configuration to
  justify revisiting the already validated setup?
