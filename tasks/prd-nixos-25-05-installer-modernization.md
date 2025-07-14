# PRD: NixOS 25.05 Installer Framework Modernization

## Introduction/Overview

This feature modernizes the existing NixOS bootstrap process by migrating from the current custom minimal ISO approach to NixOS 25.05's new installer framework. The current workflow involves building custom ISOs in `minimal-iso/`, booting them on target machines (Proxmox/UTM/bare metal), and then manually running disko formatting and nixos-install commands. The new framework provides built-in integration with nixos-generators and improved tooling, offering a more maintainable installation media generation process.

The goal is to replace the existing `minimal-iso/` directory with a modern implementation that leverages the new `nixos.generateInstallerImage` functionality introduced in NixOS 25.05, while preserving the current manual bootstrap workflow.

## Goals

1. **Modernize Installation Process**: Replace custom minimal ISO building with NixOS 25.05's `nixos.generateInstallerImage` framework
2. **Maintain Platform Support**: Ensure continued support for both x86_64-linux and aarch64-linux architectures
3. **Preserve Existing Functionality**: Keep SSH access, IP display, and remote flake installation capabilities
4. **Preserve Existing Workflow**: Maintain the current manual disko format + nixos-install bootstrap process
5. **Improve Maintainability**: Use officially supported installation framework instead of custom implementations

## User Stories

1. **As a system administrator**, I want to boot a modern NixOS installer ISO so that I can leverage the latest installation tools and framework improvements.

2. **As a developer**, I want to maintain a single flake configuration so that I don't need to manage separate minimal-iso builds and host configurations.

3. **As a user installing on different architectures**, I want the same streamlined installation experience on both x86_64 and aarch64 platforms so that my workflow is consistent.

4. **As someone learning NixOS**, I want to use the officially recommended installation approach so that my knowledge stays current with NixOS best practices.

5. **As a user doing remote installations**, I want SSH access and IP display functionality preserved so that I can continue my current remote installation workflow.

## Functional Requirements

1. **R1**: The system must generate installer ISOs using NixOS 25.05's `nixos.generateInstallerImage` functionality instead of the current custom minimal ISO approach.

2. **R2**: The system must support both x86_64-linux and aarch64-linux architectures with feature parity.

3. **R3**: The system must preserve SSH access functionality with the same authorized keys as the current implementation.

4. **R4**: The system must maintain the IP display feature on console login to show connection instructions.

5. **R5**: The system must include all necessary tools (disko, parted, e2fsprogs, etc.) via the new `nixos-install-tools` package collection.

6. **R6**: The system must integrate with the existing disko configurations for disk formatting.

7. **R7**: The system must support installation of the existing host configurations (`minimal-arm64` and `minimal-amd64`) from the remote flake.

8. **R8**: The system must include essential system packages (wget, curl, htop, emacs-nox, git, fastfetch) for troubleshooting and maintenance.

9. **R9**: The system must enable experimental Nix features (nix-command, flakes) for modern Nix functionality.

10. **R10**: The generated ISOs must be bootable on Proxmox VMs, UTM VMs, and bare metal hardware.

## Non-Goals (Out of Scope)

1. **Changing Host Configurations**: This feature will not modify the existing `host/minimal/` configurations or their functionality.

2. **Backwards Compatibility**: The old `minimal-iso/` approach will be replaced entirely; no backwards compatibility is required.

3. **New Installation Targets**: No new architectures or installation targets beyond the current x86_64-linux and aarch64-linux.

4. **UI/UX Changes**: No changes to the console experience beyond what the new framework provides by default.

5. **Workflow Automation**: The new implementation will not change the current manual bootstrap process; users will continue to manually execute disko formatting and nixos-install commands as they do today.

## Technical Considerations

1. **Migration Strategy**: The new implementation should be developed in parallel before removing the old `minimal-iso/` directory.

2. **NixOS 25.05 Dependency**: This feature requires upgrading to NixOS 25.05, which may involve updating other parts of the flake.

3. **Flake Structure**: It's unclear whether the new installer configurations can or should be integrated into the main flake.nix or maintained as a separate flake like the current approach.

4. **Testing Requirements**: Both generated ISOs must be tested on Proxmox and UTM before considering the migration complete.

5. **Documentation Updates**: The README.md and any installation documentation must be updated to reflect the new process.

## Success Metrics

1. **Functional Parity**: Successfully boot and install NixOS using the new framework on both x86_64 and aarch64 architectures.

2. **Modernized Implementation**: Successfully replace the custom minimal ISO approach with NixOS 25.05's official installer framework, whether as a separate flake or integrated into the main flake.

3. **Maintained Workflow**: Preserve the existing SSH-based remote installation workflow without breaking changes.

4. **Faster Development**: Reduce the complexity of making changes to the installer configuration.

5. **Community Alignment**: Use officially supported NixOS installation methods rather than custom implementations.

## Open Questions

1. **Disko Integration Approach**: Should we embed disko configurations directly in the installer image for automatic formatting, or maintain the current manual approach initially?

2. **Flake Organization**: Should the new installer configurations be integrated into the main flake.nix, or is it better/necessary to maintain them as a separate flake like the current `minimal-iso/` approach?

3. **Testing Strategy**: What specific test scenarios should be validated before considering the migration complete?

4. **Upgrade Path**: Should we research and document any breaking changes or considerations when moving from NixOS 24.11 to 25.05?
