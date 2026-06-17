#!/bin/bash
set -e

export DOCKER_BUILDKIT=1

docker build \
  -t quokka-cuda-claude:quokka-amd64 \
  -f ./Dockerfile .

docker build \
  -t quokka-cuda-claude:arm64 \
  -f ./Dockerfile.arm64 .
