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
# Using multi-arch nixos/nix:latest causes problems
# Preferred: Use single arch, pinned tags nixos/nix:2.28.3-amd64, nixos/nix:2.28.3-arm64
# NIXOS_DOCKER_IMAGE="nixos/nix:latest"
NIXOS_DOCKER_IMAGE="nixos/nix:2.28.3"

# Set architectures based on OS
case "$(uname -s)" in
    Darwin)
        # On macOS, build for both architectures
        ARCHS=("aarch64" "x86_64")
        ;;
    Linux)
        # On Linux, build only for current architecture
        ARCHS=("$(uname -m)")
        ;;
    *)
        echo "Error: Unsupported operating system: $(uname -s)" >&2
        exit 1
        ;;
esac

# Map architectures to Docker platforms, e.g. docker run --platform linux/amd64
declare -A PLATFORM_MAP=(
    ["x86_64"]="amd64"
    ["aarch64"]="arm64"
)

# Get current user and group IDs for Docker volume mounting
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Common Docker options
# Using -i flag to ensure output (EOT) is properly captured
DOCKER_OPTS="--rm -i -e HOME=/repo -v ${REPO_ROOT}:/repo -w /repo"

# Command to run bash in a cross-platform way
BASH_CMD="env bash"

echo "## Configuration"
echo "- NixOS Docker Image (platform): ${NIXOS_DOCKER_IMAGE}-${PLATFORM_MAP[${ARCHS[0]}]}"
echo "- Architectures: ${ARCHS[*]}"
echo "- User ID: ${USER_ID}, Group ID: ${GROUP_ID}"
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
ARCH="${ARCHS[0]}"
docker run ${DOCKER_OPTS} --platform "linux/${PLATFORM_MAP[$ARCH]}" ${NIXOS_DOCKER_IMAGE}-${PLATFORM_MAP[$ARCH]} env bash <<EOT
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
    echo "- NixOS Docker Image (platform): ${NIXOS_PLATFORM_DOCKER_IMAGE}"
    echo ""
    
    echo "Building..."
    # ISO_OUT_DIR="${SCRIPT_DIR}/isos"
    # mkdir -p "${ISO_OUT_DIR}"
    # Docker sandboxing issues (seccomp) under qemu-emulated amd64 on macOS
    # Workarounds applied:
    #   1. --security-opt seccomp=unconfined   → disable Docker-level seccomp
    #   2. nix --option filter-syscalls false  → disable Nix's internal seccomp filter
    
    # HEREDOC BEHAVIOR:
    # - With unquoted <<EOT: Both $variables and $(command) substitutions happen on HOST before content is sent to container
    # - With quoted <<'EOT': No substitutions occur, everything is passed literally to the container
    # - We need to use unquoted heredoc to pass BUILD_TARGET from host to container
    docker run ${DOCKER_OPTS} --security-opt seccomp=unconfined --platform ${DOCKER_PLATFORM} ${NIXOS_PLATFORM_DOCKER_IMAGE} bash <<EOT
# set -x # for tracing
echo "Nix version: $(nix --version)"
echo "Building for target: ${BUILD_TARGET}"
# remove the result (usually a nix store path link) directory
# so we don't get spurious 'Git tree '/repo' is dirty' warnings
# use || true to prevent errors if directory doesn't exist
rm -rf result || true
nix --extra-experimental-features 'nix-command flakes' --option filter-syscalls false \
    build --quiet .#nixosConfigurations.${BUILD_TARGET}.config.system.build.images.iso-installer
    
# Find the ISO file (there should be only one)
ISO_FILE=\$(find result/iso -name "*.iso" -type f | head -n 1)

# Check if we actually found an ISO file
if [ -z "\${ISO_FILE}" ]; then
  echo "✗ ERROR: No ISO file found in result/iso directory!"
  exit 1
fi

echo "ISO file: \${ISO_FILE}"
# Calculate checksum of the ISO inside the container
sha256sum \${ISO_FILE}
du -sh \${ISO_FILE}
# now copy it out to the hosts' current directory (mounted as /repo) with nu- prefix
cp \${ISO_FILE} /repo/nu-\$(basename \${ISO_FILE})
EOT
    echo "✓ Completed ${ARCH} build"
    echo ""
done

echo "## Copied ISO digests (host)"
sha256sum nu-*.iso
echo ""


echo "## Completion"
echo ""
echo "✓ All installer ISOs built successfully"
echo "" 