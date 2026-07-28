# niri-desktop — Evaluate a Standalone Niri Desktop

## Outcome

Determine whether Niri's native scrollable compositor model justifies replacing
the GNOME session after PaperWM establishes which scrolling behavior matters in
practice.

This is intentionally separate from [paperwm-trial](paperwm-trial.md). Shared
rationale is in [scrolling-desktop](../design/scrolling-desktop.md).

## Why Separate

PaperWM changes window arrangement while retaining GNOME's session. Niri would
change the compositor and require explicit ownership of the surrounding desktop
session.

The evaluation must account for:

- vertically arranged workspaces;
- horizontal columns and optional vertical stacks within a column;
- independent workspace stacks per monitor;
- locking, logout, notifications, screenshots, portals, display configuration,
  and session startup;
- replacement of GNOME-specific readiness and window-state probes in the desktop
  harness;
- removal or replacement of the GNOME extension used by keyd's application
  mapper;
- recovery to a known graphical session if the Niri session fails.

## Entry Criteria

- The simplified keybinding model is settled.
- PaperWM has produced real-hardware evidence about scrollable tiling.
- Daniel can name the Niri-specific behavior worth the larger session scope.
- A plan identifies the complete desktop-session boundary and recovery path.

## Open

- Is Niri primarily a later experiment or already the likely long-term target if
  PaperWM validates the scrolling model?
- Which host and display topology best exercise independent workspace stacks?
- Does the Niri scaffold create the right first consumer for the chosen module
  architecture and user-configuration ownership?
- What daily-use period and acceptance evidence would support replacing GNOME?
