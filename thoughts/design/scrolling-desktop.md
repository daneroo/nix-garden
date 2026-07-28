# Scrollable Desktop

Status: draft

## Decision

Evaluate scrollable tiling as the desktop-level spatial model without treating
PaperWM and Niri as interchangeable implementations or one binary compositor
choice.

Execute PaperWM first as a low-risk experiment inside the existing GNOME
desktop. Treat a standalone Niri desktop as separate, later work whose larger
session-integration cost is justified only by evidence from using the scrolling
model.

Traditional dense tiling is not the goal. The desired behavior is to keep
desktop applications large and readable while gaining stable spatial placement
and fast keyboard navigation. Dense splitting remains useful inside terminals
and other contexts that benefit from it.

## Shared Spatial Model

PaperWM and Niri both avoid forcing every open window into the visible viewport.
Windows can retain comfortable widths in a horizontal surface that scrolls
beyond the monitor.

The expected benefits are:

- Existing windows do not constantly shrink and rearrange when another opens.
- Large application surfaces remain useful.
- Window placement builds spatial memory.
- Keyboard navigation remains predictable.
- Desktop-level layout stays sparse while terminal-local layouts can be dense.

The experiment is successful only if those benefits appear in daily use; being
described as a tiling window manager is not itself valuable.

## Modifier Ownership

Settle the simplified keybinding model before the PaperWM trial:

| Modifier | Intended ownership                        |
| -------- | ----------------------------------------- |
| Alt      | Command-like application semantics        |
| Super    | Desktop, workspace, and window navigation |
| Ctrl     | Native Unix/Linux Control semantics       |

This separation should remain stable across GNOME, PaperWM, and any later Niri
session. A desktop implementation may change the functional hook for a
Super-based action, but it should not redefine the physical application
modifier.

Per-application compatibility remains necessary regardless of the desktop.
Electron applications and modern GTK applications do not provide one universal
shortcut configuration surface. Do not expect either PaperWM or Niri to remove
that boundary automatically.

## PaperWM First

PaperWM adds horizontally scrollable tiling to GNOME Shell. The existing desktop
continues to own:

- settings and display integration;
- notifications and overview;
- lock, logout, and session handling;
- Bluetooth and ordinary desktop plumbing;
- Mutter as the Wayland compositor.

This makes PaperWM the quickest reversible way to answer the behavioral
question: does scrolling spatial window management fit Daniel's real workflow?

The trial must check:

- comfortable window widths and stable placement;
- horizontal keyboard navigation and trackpad behavior;
- multi-monitor behavior;
- interaction with GNOME workspaces and overview;
- ownership of Super-based desktop bindings;
- compatibility with the patched keyd application-mapper GNOME extension;
- persistence across logout, login, and reboot;
- transfer of the existing observable desktop harness.

PaperWM is not expected to remove GNOME's bundled applications, GNOME-owned
bindings, or the patched application-mapper extension. Those are reasons a later
Niri session may still be attractive, not reasons to burden the initial trial.

## Niri Later

Niri implements scrollable tiling as a standalone Wayland compositor. Its
stronger spatial hypothesis is orthogonal navigation:

- left/right moves among windows or columns within a workspace;
- windows may stack vertically inside a column;
- up/down moves among vertically arranged workspaces;
- each monitor has an independent workspace stack.

That model may be cleaner and more coherent than implementing scrolling on top
of GNOME. It also requires assembling and owning the session components GNOME
currently supplies, including locking, notifications, screenshots, logout,
display configuration, portals, and other desktop integration.

Niri therefore gets its own ticket and eventual plan. Do not hide that
session-construction work inside the PaperWM experiment or use a successful
PaperWM trial as automatic authorization to replace GNOME.

## Prior Alternatives

- **Hyprland / Omarchy** — useful prior evidence for conventional dense tiling,
  but opening windows rearranged the visible layout in a way that did not fit
  the desired large-surface workflow. It is no longer a leading candidate.
- **GNOME without scrolling tiling** — remains the recovery baseline and the
  control against which PaperWM is judged.

## Sequencing

1. Settle and verify the simplified keybinding model on `hardy`, then `gauss`.
2. Execute the bounded PaperWM trial without waiting for a repository-wide
   module refactor.
3. Decide whether the scrolling model is useful in real work.
4. If PaperWM is worth productionizing across hosts, choose the reusable
   user/session ownership and module boundary before expanding its
   configuration.
5. Open a Niri implementation plan only when its distinct spatial model and
   removal of GNOME justify the larger desktop-session scope.

## Open Questions

- Which PaperWM motions and window operations become daily muscle memory?
- Does PaperWM preserve or improve the existing GNOME overview workflow?
- Can PaperWM coexist reliably with the application-mapper extension?
- Which multi-monitor behavior matters on the actual hardware?
- Can the VM harness prove configuration and regressions while leaving animation
  and feel to real hardware?
- Which PaperWM findings would specifically justify moving to Niri rather than
  simply keeping PaperWM?
- Does Niri's vertical workspace axis and independent per-monitor stack feel as
  natural in practice as it sounds conceptually?
- Which GNOME session components would a Niri desktop need to replace, and who
  owns their configuration?
