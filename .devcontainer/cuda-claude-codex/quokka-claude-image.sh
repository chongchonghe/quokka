#!/usr/bin/env bash
# Build and push (macOS), pull (Linux with CUDA), or delete the quokka cuda-claude-codex image.

set -euo pipefail

export DOCKER_BUILDKIT=1

REGISTRY=ghcr.io/chongchonghe
DEFAULT_PLATFORM=amd64

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h] [--platform amd64|arm64] [build|push|pull|delete]

With no command, build the image and push it to GitHub Packages (macOS only).

Commands:
  build                  Build the image locally, do not push (macOS only)
  push                   Push the already-built image (macOS only)
  pull                   Pull the image as a Singularity .sif (Linux with CUDA only)
  delete                 Delete the image from the local computer

Options:
  --platform PLATFORM    amd64 (default, uses Dockerfile) or arm64 (uses Dockerfile.arm64)
  -h, --help             Show this message and exit

Images: $REGISTRY/quokka-linux-<platform>-cuda-claude-codex:latest

The image is private. Before 'pull', set SINGULARITY_DOCKER_USERNAME and
SINGULARITY_DOCKER_PASSWORD (APPTAINER_DOCKER_* for Apptainer) to a token with read:packages.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

platform=$DEFAULT_PLATFORM
command=all

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)
            [[ $# -ge 2 ]] || { echo "error: --platform needs a value" >&2; usage >&2; exit 1; }
            platform=$2; shift 2 ;;
        --platform=*) platform=${1#--platform=}; shift ;;
        build|push|pull|delete) command=$1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument '$1'" >&2; usage >&2; exit 1 ;;
    esac
done

case "$platform" in
    amd64) dockerfile=./Dockerfile ;;
    arm64) dockerfile=./Dockerfile.arm64 ;;
    *) echo "error: unknown platform '$platform'" >&2; usage >&2; exit 1 ;;
esac

image=$REGISTRY/quokka-linux-$platform-cuda-claude-codex:latest
sif=quokka-linux-$platform-cuda-claude-codex.sif

require_macos() {
    [[ $(uname -s) == Darwin ]] || die "'$command' must run on macOS"
}

require_linux_cuda() {
    [[ $(uname -s) == Linux ]] || die "'$command' must run on Linux"
    command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1 || die "no CUDA GPU found (nvidia-smi failed)"
}

build() {
    require_macos
    docker build --platform "linux/$platform" -t "$image" -f "$dockerfile" .
}

push() {
    require_macos
    docker push "$image"
}

pull() {
    require_linux_cuda
    local singularity
    singularity=$(command -v singularity || command -v apptainer) || die "singularity or apptainer not found"
    "$singularity" pull --force "$sif" "docker://$image"
}

delete() {
    docker rmi "$image"
}

case "$command" in
    all) build; push ;;
    build) build ;;
    push) push ;;
    pull) pull ;;
    delete) delete ;;
esac
