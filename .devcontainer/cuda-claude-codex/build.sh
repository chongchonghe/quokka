#!/bin/bash
set -e

export DOCKER_BUILDKIT=1

IMAGE=ghcr.io/chongchonghe/quokka-linux-amd64-cuda-claude-codex

docker build \
  --platform linux/amd64 \
  -t "${IMAGE}:latest" \
  -f ./Dockerfile .

docker push "${IMAGE}:latest"

# docker build \
#   -t quokka-cuda-claude:arm64 \
#   -f ./Dockerfile.arm64 .
