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
ARCHS=("aarch64" "x86_64")

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
    # ISO_OUT_DIR="${SCRIPT_DIR}/isos"
    # mkdir -p "${ISO_OUT_DIR}"
    # Docker sandboxing issues (seccomp) under qemu-emulated amd64 on macOS
    # Work-arounds applied:
    #   1. --security-opt seccomp=unconfined   → disable Docker-level seccomp
    #   2. nix --option filter-syscalls false  → disable Nix's internal seccomp filter
    docker run --rm --security-opt seccomp=unconfined --platform ${DOCKER_PLATFORM} -v ${REPO_ROOT}:/repo -w /repo ${NIXOS_DOCKER_IMAGE} \
        bash -euo pipefail -c "\
        set -x
        nix --extra-experimental-features 'nix-command flakes' --option filter-syscalls false \\
            build --quiet .#nixosConfigurations.${BUILD_TARGET}.config.system.build.images.iso-installer
            
        # Calculate checksum of the ISO inside the container
        ls -la result/
        if [ -d result/iso ]; then
            ls -la result/iso/
            iso_file=\"result/iso/nixos-25.05.20250605.4792576-${ARCH}-linux.iso\"
            if [ -f \$iso_file ]; then
                echo \"  - ISO file: \$(basename \$iso_file)\"
                echo \"  - SHA256: \$(sha256sum \$iso_file | cut -d' ' -f1)\"
            else
                echo \"ERROR: ISO file not found at \$iso_file\"
                find result -name \"*.iso\" -type f
            fi
        else
            echo \"ERROR: result/iso directory not found\"
            ls -la result
            readlink result
        fi"
    echo "TODO: Copy out artifacts later"
    echo ""
    
    echo "✓ Completed ${ARCH} build"
    echo ""
done

echo "## Completion"
echo ""
echo "✓ All installer ISOs built successfully"
echo "" 