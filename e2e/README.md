# NixOS Installation End-to-End Testing

## Objectives

Test the complete NixOS installation process from ISO creation to system boot, focusing on:

- Automated testing of the new NixOS 25.05 installer framework
- x86_64/proxmox for now, aarch64/tart-vm later

Process:

- Create VM with iso already present,
- Boot from ISO,
- Recreate installer iso in installer - validate checksum
- Format disk and install NixOS, verify installation
- Recreate installer iso again - validate checksum
- Cleanup VM

## Requirements

- Minimize manual SSH interactions with Proxmox host
- Single SSH connection to copy and execute test script
- Configurable VM parameters (memory, disk size, cores)

## Invocation

```bash
./proxmox-bootstrap.sh
# or from parent directory
./e2e/proxmox-bootstrap.sh
```

## Tasks

- [ ] make a simple script copy to host and execute - only echo parameters
- [ ] confirm iso is present, with sha256
- [ ] list vms
- [ ] find vm by id
- [ ] create vm if id does not exist