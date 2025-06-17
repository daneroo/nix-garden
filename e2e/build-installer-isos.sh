#!/usr/bin/env bash
set -euo pipefail

echo "# Build Installer ISOs Script"
echo ""

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "- Script Directory: ${SCRIPT_DIR}"
echo "- Repo Root: ${REPO_ROOT}"
echo ""

# Configuration
# Using multi-arch nixos/nix:latest image which automatically selects the right architecture
# Alternative: could use single arch images like nixos/nix:latest-amd64, nixos/nix:latest-arm64
NIXOS_DOCKER_IMAGE="nixos/nix:latest"
ARCHS=("x86_64" "aarch64")

# Map architectures to build targets
declare -A BUILD_TARGET_MAP=(
    ["x86_64"]="installer-x86_64"
    ["aarch64"]="installer-aarch64"
)

# Map architectures to Docker platforms
declare -A DOCKER_PLATFORM_MAP=(
    ["x86_64"]="linux/amd64"
    ["aarch64"]="linux/arm64"
)

echo "## Configuration"
echo "- Docker Image: ${NIXOS_DOCKER_IMAGE}"
echo "- Architectures: ${ARCHS[*]}"
echo ""

# Show flake structure
echo "## Flake Structure"
echo ""
docker run --rm --platform linux/amd64 -v ${REPO_ROOT}:/repo -w /repo ${NIXOS_DOCKER_IMAGE} \
    nix --extra-experimental-features "nix-command flakes" flake show --quiet --all-systems
echo ""

# Build ISOs for each architecture
for ARCH in "${ARCHS[@]}"; do
    echo "## Building ${ARCH} Installer ISO"
    echo ""
    
    BUILD_TARGET="${BUILD_TARGET_MAP[$ARCH]}"
    DOCKER_PLATFORM="${DOCKER_PLATFORM_MAP[$ARCH]}"
    
    echo "- Architecture: ${ARCH}"
    echo "- Build Target: ${BUILD_TARGET}"
    echo "- Docker Platform: ${DOCKER_PLATFORM}"
    echo ""
    
    echo "Building..."
    # Note: Docker containers have sandboxing issues with seccomp BPF
    # Options: --privileged (enables proper sandboxing) or --option sandbox false (disables sandboxing)
    # We assume sandboxing is not critical for building NixOS ISOs from trusted sources
    docker run --rm --platform ${DOCKER_PLATFORM} -v ${REPO_ROOT}:/repo -w /repo ${NIXOS_DOCKER_IMAGE} \
        nix --extra-experimental-features "nix-command flakes" --option sandbox false \
        build --quiet .#nixosConfigurations.${BUILD_TARGET}.config.system.build.images.iso-installer
    
    echo ""
    echo "Calculating digest of built iso..."
    
    # Find and checksum ISO files in result/iso/
    if [ -d "result/iso" ]; then
        echo "ISO files found:"
        for iso_file in result/iso/nixos*.iso; do
            if [ -f "$iso_file" ]; then
                echo "  - File: $(basename $iso_file)"
                echo "  - Size: $(du -h "$iso_file" | cut -f1)"
                echo "  - SHA256: $(sha256sum "$iso_file" | cut -d' ' -f1)"
                echo ""
            fi
        done
    else
        echo "✗ WARNING: No result/iso directory found"
    fi
    
    # TODO: Copy out artifacts (implement later)
    echo "TODO: Copy out artifacts"
    echo ""
    
    echo "✓ Completed ${ARCH} build"
    echo ""
done

echo "## Completion"
echo ""
echo "✓ All installer ISOs built successfully"
echo "" 