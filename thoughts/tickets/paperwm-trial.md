# paperwm-trial — Test Scrollable Tiling Inside GNOME

## Outcome

Determine whether PaperWM's horizontally scrollable window model improves
Daniel's real desktop workflow enough to keep and productionize, without
replacing the existing GNOME session.

Shared rationale and the later Niri boundary are in
[scrolling-desktop](../design/scrolling-desktop.md).

## Boundaries

- Run after `simplified-keybinding-model` settles Alt, Super, and Ctrl
  ownership.
- Keep GNOME, Mutter, and the current session services.
- Preserve GNOME without PaperWM as a recoverable login/session baseline.
- Do not include a flake-parts or broad module migration in the behavioral
  trial.
- Do not turn this into a Niri session scaffold.

## Evidence to Collect

- Daily-use feel of stable, comfortably sized horizontal windows.
- Keyboard, pointer, and trackpad navigation.
- Window opening, closing, moving, sizing, and workspace behavior.
- Single- and multi-monitor behavior on available hardware.
- PaperWM and patched application-mapper extension compatibility.
- Existing lock, logout, screenshot, launcher, 1Password, and application
  bindings.
- Logout/login and reboot persistence.
- Which existing headless E2E assertions transfer unchanged and which
  PaperWM-specific window-state observations are needed.

## Acceptance

- The trial is reversible without endangering the GNOME baseline.
- Existing application-keybinding behavior remains covered by the observable
  desktop tests.
- Daniel can judge the workflow on real hardware, not only through a VM.
- The outcome records what was better, worse, or merely different.
- A successful trial identifies the smallest reusable configuration boundary; it
  does not automatically authorize fleet-wide adoption or Niri work.

## Open

- Which host should receive the first PaperWM session after keybindings settle?
- Should the first real-hardware trial use an alternate session, specialisation,
  or ordinary extension enablement with a tested disable path?
- What exact compatibility check proves that both GNOME extensions remain
  reliable together?
- How long is enough daily use to distinguish novelty from durable ergonomics?
