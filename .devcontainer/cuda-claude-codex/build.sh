#!/usr/bin/env bash
# Build, push, or delete the quokka cuda-claude-codex image.

set -euo pipefail

export DOCKER_BUILDKIT=1

IMAGE=ghcr.io/chongchonghe/quokka-linux-amd64-cuda-claude-codex:latest
PLATFORM=amd64
DOCKERFILE=./Dockerfile

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h] [build|push|delete]

With no argument, build the image and push it to GitHub Packages.

Commands:
  build         Build the image locally, do not push
  push          Push the already-built image
  delete        Delete the image from the local computer
  -h, --help    Show this message and exit

Image: $IMAGE
EOF
}

build() {
    docker build --platform "$PLATFORM" -t "$IMAGE" -f "$DOCKERFILE" .
}

push() {
    docker push "$IMAGE"
}

delete() {
    docker rmi "$IMAGE"
}

if [[ $# -gt 1 ]]; then
    usage >&2
    exit 1
fi

case "${1:-all}" in
    all) build; push ;;
    build) build ;;
    push) push ;;
    delete) delete ;;
    -h|--help) usage ;;
    *) echo "error: unknown command '$1'" >&2; usage >&2; exit 1 ;;
esac

# docker build \
#   -t quokka-cuda-claude:arm64 \
#   -f ./Dockerfile.arm64 .
