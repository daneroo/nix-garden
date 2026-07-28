# Tiling Windows

PaperWM provides scrollable tiling inside the existing GNOME session on `hardy`
and `gauss`. GNOME and Mutter continue to own the session, displays, overview,
lock screen, notifications, and ordinary desktop integration.

## Spatial Model

Windows occupy a horizontally scrolling strip without being compressed into the
visible viewport. Dragging reorders windows and can create a vertical stack.
Workspaces remain a vertical axis.

Useful defaults confirmed on real hardware:

- `Super+,` and `Super+.` move between windows.
- `Super+PageUp` and `Super+PageDown` move between workspaces.
- `Ctrl+Super+Escape` moves the focused window to or from PaperWM's floating
  scratch layer.

`Alt+Super+Left` and `Alt+Super+Right` overlap PaperWM's adjacent-monitor
workspace actions and are not part of the accepted navigation map. The broader
modifier and application contract remains in [keybindings](keybindings.md).

## Enabled State

Nix always installs PaperWM and `paperwm-toggle` on both hosts. The GNOME system
default enables PaperWM for a fresh user profile. After that, the user's last
enabled or disabled choice persists; applying NixOS does not continuously
enforce the choice.

Run `paperwm-toggle` from a shell, or search for **Toggle PaperWM Tiling** in
Vicinae. Enabling restores scrollable tiling; disabling returns the live session
to ordinary GNOME window placement.

The equivalent low-level commands are:

```bash
gnome-extensions enable paperwm@paperwm.github.com
gnome-extensions disable paperwm@paperwm.github.com
```

GNOME reports extensions inactive while the screen is locked. That transient
runtime state does not mean the persistent enabled choice was lost.

## Vicinae

PaperWM classifies Vicinae's `vicinae` window as scratch-layer content, so the
launcher floats instead of consuming a tiled column.

The shared PaperWM module packages one toggle implementation and exposes it
through both:

```text
/run/current-system/sw/bin/paperwm-toggle
/run/current-system/sw/share/vicinae/scripts/paperwm-toggle
```

Vicinae discovers the second path through `XDG_DATA_DIRS`. Both paths belong to
the NixOS generation, so removing the package removes both surfaces without
leaving an artifact in Daniel's home.

## Configuration and Recovery

[`modules/paperwm.nix`](../modules/paperwm.nix) owns the shared extension and
toggle package. Each host declares the same fresh-profile enabled default and
Vicinae scratch rule alongside its existing GNOME settings. This focused shared
module is useful precedent, but it does not complete the broader
`module-architecture` backlog item.

Both hosts passed real-session installation, enable/disable, tiling, floating,
workspace, logout/login, and Vicinae discovery checks. Apply a clean generation
from `main`, or select the previous NixOS generation, if the extension prevents
normal desktop use.
