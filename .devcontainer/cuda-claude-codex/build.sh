#!/usr/bin/env bash
# Build, push, or delete the quokka cuda-claude-codex image.

set -euo pipefail

export DOCKER_BUILDKIT=1

REGISTRY=ghcr.io/chongchonghe
DEFAULT_PLATFORM=amd64

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h] [--platform amd64|arm64] [build|push|delete]

With no command, build the image and push it to GitHub Packages.

Commands:
  build                  Build the image locally, do not push
  push                   Push the already-built image
  delete                 Delete the image from the local computer

Options:
  --platform PLATFORM    amd64 (default, uses Dockerfile) or arm64 (uses Dockerfile.arm64)
  -h, --help             Show this message and exit

Images: $REGISTRY/quokka-linux-<platform>-cuda-claude-codex:latest
EOF
}

platform=$DEFAULT_PLATFORM
command=all

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)
            [[ $# -ge 2 ]] || { echo "error: --platform needs a value" >&2; usage >&2; exit 1; }
            platform=$2; shift 2 ;;
        --platform=*) platform=${1#--platform=}; shift ;;
        build|push|delete) command=$1; shift ;;
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

build() {
    docker build --platform "linux/$platform" -t "$image" -f "$dockerfile" .
}

push() {
    docker push "$image"
}

delete() {
    docker rmi "$image"
}

case "$command" in
    all) build; push ;;
    build) build ;;
    push) push ;;
    delete) delete ;;
esac
