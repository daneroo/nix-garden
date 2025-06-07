# Tasks: NixOS 25.05 Installer Framework Modernization

## Relevant Files

- `flake.nix` - Main repository flake that may need NixOS 25.05 upgrade and potentially new installer configurations
- `minimal-iso/flake.nix` - Current custom minimal ISO flake to be replaced/modernized
- `minimal-iso/flake.lock` - Current flake lock file for minimal ISO
- `installer/flake.nix` - New installer flake using generateInstallerImage (if keeping separate approach)
- `installer/flake.lock` - Lock file for new installer flake
- `README.md` - Main documentation that needs updates for new installation process
- `host/minimal/configuration.nix` - Existing minimal host config (should remain unchanged per PRD)
- `disko/` - Existing disko configurations (should remain unchanged per PRD)
- `scripts/disko-format-install/` - Bootstrap scripts that may need updates to reference new ISO locations

### Notes

- The PRD indicates uncertainty about whether to integrate installer configs into main flake or keep separate
- Current `host/minimal/` and `disko/` configurations should remain unchanged per non-goals
- Testing will require building ISOs and validating on Proxmox/UTM platforms

## Tasks

- [ ] 1.0 Research and Understand NixOS 25.05 Installer Framework
  - [x] 1.1 Study NixOS 25.05 release notes for installer framework changes
  - [x] 1.2 Research `nixos.generateInstallerImage` functionality and API
  - [x] 1.3 Investigate `nixos-install-tools` package collection contents
  - [x] 1.4 Compare new framework with current `minimal-iso/flake.nix` approach
  - [x] 1.5 Determine if installer configs should be integrated into main flake or kept separate
  - [x] 1.6 Document findings and create implementation plan
- [x] 2.0 Upgrade Dependencies to NixOS 25.05
  - [x] 2.1 Update main `flake.nix` to use NixOS 25.05 inputs
  - [x] 2.2 Update `flake.lock` and test existing configurations still work
  - [x] 2.3 Verify `host/minimal/` configurations are compatible with NixOS 25.05
  - [x] 2.4 Check for any breaking changes affecting current disko/install workflow
  - [x] 2.5 Update any other flakes in repository to NixOS 25.05 if necessary
- [ ] 3.0 Implement New Installer Configuration Using generateInstallerImage
  - [ ] 3.1 Create new installer flake structure (separate or integrated based on research)
  - [ ] 3.2 Implement `generateInstallerImage` configuration for x86_64-linux
  - [ ] 3.3 Implement `generateInstallerImage` configuration for aarch64-linux
  - [ ] 3.4 Migrate SSH key configuration and authorized users setup
  - [ ] 3.5 Migrate IP display functionality for console login
  - [ ] 3.6 Include necessary system packages (wget, curl, htop, emacs-nox, git, fastfetch)
  - [ ] 3.7 Ensure nixos-install-tools and disko are available in installer environment
  - [ ] 3.8 Enable experimental Nix features (nix-command, flakes)
  - [ ] 3.9 Test ISO generation for both architectures
- [ ] 4.0 Test and Validate New Installer Implementation
  - [ ] 4.1 Build and test x86_64-linux ISO generation
  - [ ] 4.2 Build and test aarch64-linux ISO generation
  - [ ] 4.3 Test booting x86_64 ISO on Proxmox VM
  - [ ] 4.4 Test booting aarch64 ISO on UTM VM
  - [ ] 4.5 Validate SSH access works with existing authorized keys
  - [ ] 4.6 Validate IP display functionality shows correct connection instructions
  - [ ] 4.7 Test complete disko + nixos-install workflow using remote flake
  - [ ] 4.8 Verify installation of existing `minimal-arm64` and `minimal-amd64` configurations
  - [ ] 4.9 Test on bare metal hardware if available
- [ ] 5.0 Update Documentation and Clean Up Legacy Implementation
  - [ ] 5.1 Update README.md with new ISO building instructions
  - [ ] 5.2 Update README.md bootstrap workflow documentation
  - [ ] 5.3 Update any build commands and examples in documentation
  - [ ] 5.4 Remove old `minimal-iso/` directory and files
  - [ ] 5.5 Update `scripts/disko-format-install/` if needed to reference new ISO locations
  - [ ] 5.6 Commit changes and update any CI/automation that builds ISOs
