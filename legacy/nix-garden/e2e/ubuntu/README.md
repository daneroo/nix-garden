# Ubuntu 24.04 + GNOME + RustDesk on Proxmox

## Objective

- [x] Fully automated, repeatable provisioning of an Ubuntu 24.04 VM with GNOME desktop and RustDesk
      remote access.
- [x] No hardware dependencies. Works on any Proxmox host.
- [x] Connect from macOS via RustDesk directly by LAN IP.

## Usage

```bash
./provision.sh              # VM 996 (default)
./provision.sh --vmid 993   # VM 993
./provision.sh --help
```

**Connect**: open RustDesk on macOS → enter `<VM IP>` → password `daniel123`

**Destroy**: `ssh root@hilbert 'qm stop 996 && qm destroy 996 --purge'`

## How it works

- Cloud image import — no installer, boots in ~3.5 min
- GNOME (`ubuntu-desktop-minimal`) installed over SSH
- NetworkManager replaces systemd-networkd (desktop default); VM IP may change on reboot, re-resolved via qemu-guest-agent
- GDM forced to X11 (`WaylandEnable=false`) — RustDesk does not support Wayland login screens
- RustDesk installed after reboot; service stopped before password/options are set, then restarted
- GNOME user session runs Wayland natively; RustDesk uses AV1 codec for the session

## Prerequisites

Cloud image must be present on the Proxmox host before provisioning:

```bash
ssh root@hilbert 'wget -P /pve-storage/backups-isos/template/iso/ https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img'
```

## Files

- `provision.sh` — runs on macOS; orchestrates the full provisioning
- `on-proxmox-img.sh` — runs on Proxmox (piped via SSH); creates the VM from cloud image

## Known limitations

- **GDM→GNOME session handoff**: RustDesk connection resets twice during login (GDM X11 → GNOME Wayland transition). Reconnect automatically or manually — the GNOME session works well once established.
- **GDM login screen is X11**: Required by RustDesk (official limitation). The GNOME user session runs Wayland with AV1 codec and good performance.

## RustDesk config race

`sudo rustdesk --password` works with the service stopped (writes to root's config file).
`sudo rustdesk --option` requires the IPC socket (service running) and only reaches root's
config — the gdm subprocess that does the actual serving never picks it up.

Fix: stop service, set password via CLI, write `direct-server = 'Y'` directly to both config
files (`/root/.config/rustdesk/RustDesk2.toml` and `/var/lib/gdm3/.config/rustdesk/RustDesk2.toml`),
then restart. The service starts automatically on install; wait 10s before stopping to ensure
the gdm subprocess has had time to create its config files.

## History / dead ends

### xrdp

X11-only. Creates its own Xvnc/Xorg session — software rendering, unusable performance.

### GNOME Remote Desktop / RDP

Wayland-native, correct architecture. Blocked by NLA/MIC verification bug in GNOME 46 (Ubuntu 24.04)
with Microsoft's macOS RDP client. May be viable on GNOME 47+ (Ubuntu 24.10+).

### GPU passthrough + amdgpu virtual display

Attempted to pass through a GPU and use `amdgpu virtual_display` to create a headless connector.
GDM's udev rule (`61-gdm.rules`) explicitly disables Wayland when it detects virtual GPU +
passthrough GPU together — the exact combination this setup produces. Result: GDM falls back to
X11 on the virtual VGA, GPU unused, performance no better than software rendering.
Approach abandoned. No hardware dependency is the requirement.

### Multi-desktop support (--wm flag)

Script previously supported gnome/kde/xfce/none. xfce has no Wayland support; kde untested;
none is not the goal. Removed. GNOME only.
