#!/bin/bash
set -euo pipefail

IMAGE="${QUOKKA_CLAUDE_IMAGE:-quokka-cuda-claude:quokka-amd64}"
WORKSPACE="$(pwd)"
HARDCODED_GITHUB_TOKEN=$(security find-generic-password -w -s "github" -a "token")

PASS_TOKEN=1
PASS_YOLO=1
OFFLINE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--no-token] [--no-yolo] [--offline]

Start Claude inside a Quokka CUDA Docker container.

Options:
  --no-token  Do not pass GITHUB_TOKEN into the container.
  --no-yolo   Do not pass Claude's --dangerously-skip-permissions flag.
  --offline   Disable container networking.

Environment:
  QUOKKA_CLAUDE_IMAGE  Docker image to run (default: ${IMAGE})
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-token)
      PASS_TOKEN=0
      ;;
    --no-yolo)
      PASS_YOLO=0
      ;;
    --offline)
      OFFLINE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

docker_args=(
  run
  --rm
  -it
  -v "${WORKSPACE}:/home/ubuntu/workspace"
  -w /home/ubuntu/workspace
)

if [[ "${OFFLINE}" -eq 1 ]]; then
  docker_args+=(--network none)
fi

if [[ "${PASS_TOKEN}" -eq 1 ]]; then
  token="${GITHUB_TOKEN:-${HARDCODED_GITHUB_TOKEN}}"
  if [[ -n "${token}" ]]; then
    docker_args+=(-e "GITHUB_TOKEN=${token}")
  fi
fi

claude_args=(claude)
if [[ "${PASS_YOLO}" -eq 1 ]]; then
  claude_args+=(--dangerously-skip-permissions)
fi

exec docker "${docker_args[@]}" "${IMAGE}" "${claude_args[@]}"
