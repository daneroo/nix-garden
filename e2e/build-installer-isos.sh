#!/usr/bin/env bash
set -euo pipefail

# TODO:
# - [ ] Remove set +x : annoying
# - [ ] Figure out how to use EOT - heredoc
# - [ ] Justify set -euo pipefail: seems to cause more issues than safety

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
# Preferred: use pinned tags nixos/nix:2.28.3, nixos/nix:2.28.3-amd64, nixos/nix:2.28.3-arm64
# NIXOS_DOCKER_IMAGE="nixos/nix:latest"
NIXOS_DOCKER_IMAGE="nixos/nix:2.28.3"

ARCHS=("aarch64" "x86_64")

# Map architectures to Docker platforms, e.g. docker run --platform linux/amd64
declare -A PLATFORM_MAP=(
    ["x86_64"]="amd64"
    ["aarch64"]="arm64"
)

echo "## Configuration"
echo "- Docker Image: ${NIXOS_DOCKER_IMAGE}"
echo "- Architectures: ${ARCHS[*]}"
echo ""

# echo "## Check Nix Version"
# docker run --rm  ${NIXOS_DOCKER_IMAGE} nix --version
# docker run --rm --platform linux/amd64 ${NIXOS_DOCKER_IMAGE}-amd64 nix --version
# docker run --rm --platform linux/arm64 ${NIXOS_DOCKER_IMAGE}-arm64 nix --version
# echo ""
# # temporary early exit while we investigate multiple issues
# exit 0

# Figure out how to use EOT - heredoc
# print Nix version in container!
echo "## Check Nix Version and Flake Structure"
# Using -i flag to ensure output is properly captured
docker run --rm -i --platform linux/amd64 -v ${REPO_ROOT}:/repo -w /repo ${NIXOS_DOCKER_IMAGE} bash <<EOT
nix --version
nix --extra-experimental-features "nix-command flakes" flake show --quiet --all-systems
EOT
echo ""

# Build ISOs for each architecture
for ARCH in "${ARCHS[@]}"; do
    echo "## Building ${ARCH} Installer ISO"
    echo ""
    
    BUILD_TARGET="installer-${ARCH}"
    DOCKER_PLATFORM="linux/${PLATFORM_MAP[$ARCH]}"
    NIXOS_PLATFORM_DOCKER_IMAGE="${NIXOS_DOCKER_IMAGE}-${PLATFORM_MAP[$ARCH]}"
    
    echo "- Architecture: ${ARCH}"
    echo "- Build Target: ${BUILD_TARGET}"
    echo "- Docker Platform: ${DOCKER_PLATFORM}"
    echo "- NixOS Platform Docker Image: ${NIXOS_PLATFORM_DOCKER_IMAGE}"
    echo ""
    
    echo "Building..."
    # ISO_OUT_DIR="${SCRIPT_DIR}/isos"
    # mkdir -p "${ISO_OUT_DIR}"
    # Docker sandboxing issues (seccomp) under qemu-emulated amd64 on macOS
    # Work-arounds applied:
    #   1. --security-opt seccomp=unconfined   → disable Docker-level seccomp
    #   2. nix --option filter-syscalls false  → disable Nix's internal seccomp filter
    docker run --rm -i --security-opt seccomp=unconfined --platform ${DOCKER_PLATFORM} -v ${REPO_ROOT}:/repo -w /repo ${NIXOS_PLATFORM_DOCKER_IMAGE} bash <<EOT
nix --extra-experimental-features 'nix-command flakes' --option filter-syscalls false \
    build --quiet .#nixosConfigurations.${BUILD_TARGET}.config.system.build.images.iso-installer
    
# Calculate checksum of the ISO inside the container
sha256sum result/iso/*iso
du -sh result/iso/*iso
EOT
    echo "TODO: Copy out artifacts later"
    echo ""
    
    echo "✓ Completed ${ARCH} build"
    echo ""
done

echo "## Completion"
echo ""
echo "✓ All installer ISOs built successfully"
echo "" 