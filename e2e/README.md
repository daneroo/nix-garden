# NixOS Installation End-to-End Testing

These scripts validate all the components provisioning a minimal NixOS system.

## Configuration maintenance

- `./e2e/provision-install-verify-proxmox.sh`
  - names the iso image file e.g. `my-nixos-25.05.20250605.4792576-x86_64-linux.iso`
- `build-installer-isos-with-docker.sh` - (9min for both architectures)
  - uses a pinned tag for base nix image e.g. `nixos/nix:2.28.3`
    - these images work, but the digest is different from the native nix build

## Objectives

Test the complete NixOS installation process from ISO creation to system boot, focusing on:

- Automated testing of the new NixOS 25.05 installer framework
- x86_64/proxmox for now, aarch64/tart|colima-vm later

Process:

- Create VM with iso already present on proxmox,
- Boot from ISO, discover IP (ping sweep)
- Format disk and install NixOS, verify installation
- Recreate installer iso - validate checksum

## Invocation

```bash
# ssh-copy-id -i ~/.ssh/id_ed25519.pub root@hilbert
# from top level directory
./e2e/provision-install-verify-proxmox.sh
# or from current directory
./provision-install-verify-proxmox.sh
```

## Side Quest: Clan ISO password extraction

- Assumes we provisioned VMID:997 with a booted ISO (clan-nixos-installer-x86_64-linux.iso)

- Working bash script (`extract-clan-iso-password.sh`) that reliably extracts random passwords from NixOS installer VMs
- Perl conversion (`extract-clan-iso-password.pl`) for learning purposes - grew from 70 to 167 lines
- QMP protocol understanding - session continuity requirements, proper response handling
- Multiple extraction methods with performance comparison:
  - Strings method: ~38s (reference)
  - PCRE grep: ~6-8s 
  - Perl chunked: ~4s (fastest)
- Clean output formatting with progress indicators and validation
- Protocol optimization attempts - tried ID-based completion detection, learned socat connection limitations
- Reliable automation that works in test loops on Proxmox infrastructure

```bash
scp -p e2e/extract-clan-iso-password.sh root@hilbert:
scp -p e2e/extract-clan-iso-password.pl root@hilbert:

# ssh hilbert and run the script
./extract-clan-iso-password.sh
# or
./extract-clan-iso-password.pl
```
