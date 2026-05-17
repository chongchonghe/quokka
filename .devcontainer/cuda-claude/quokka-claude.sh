#!/bin/bash
set -euo pipefail

IMAGE="${QUOKKA_CLAUDE_IMAGE:-quokka-cuda-claude:quokka-amd64}"
LAUNCH_DIR="$(pwd)"
WORKSPACE_ARG=""
HOST_CLAUDE_CONFIG_DIR="${QUOKKA_CLAUDE_CONFIG_DIR:-${LAUNCH_DIR}/.claude}"
CONTAINER_CLAUDE_CONFIG_DIR="/home/ubuntu/.claude"

PASS_TOKEN=1
PASS_YOLO=1
OFFLINE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--no-token] [--no-yolo] [--offline] <workspace-dir>

Start Claude inside a Quokka CUDA Docker container.

Arguments:
  workspace-dir  Directory to mount at /home/ubuntu/workspace.

Options:
  --no-token  Do not pass GITHUB_TOKEN into the container.
  --no-yolo   Do not pass Claude's --dangerously-skip-permissions flag.
  --offline   Disable container networking.

Environment:
  QUOKKA_CLAUDE_IMAGE       Docker image to run (default: ${IMAGE})
  QUOKKA_CLAUDE_CONFIG_DIR  Host Claude config dir (default: ${HOST_CLAUDE_CONFIG_DIR})
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
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "${WORKSPACE_ARG}" ]]; then
        echo "Only one workspace directory can be provided." >&2
        usage >&2
        exit 2
      fi
      WORKSPACE_ARG="$1"
      ;;
  esac
  shift
done

if [[ -z "${WORKSPACE_ARG}" ]]; then
  echo "Missing workspace directory." >&2
  usage >&2
  exit 2
fi

WORKSPACE="${WORKSPACE_ARG}"
if [[ "${WORKSPACE}" != /* ]]; then
  WORKSPACE="${LAUNCH_DIR}/${WORKSPACE}"
fi

if [[ ! -d "${WORKSPACE}" ]]; then
  echo "Workspace directory does not exist: ${WORKSPACE}" >&2
  exit 1
fi

mkdir -p "${HOST_CLAUDE_CONFIG_DIR}"

docker_args=(
  run
  --rm
  -it
  -v "${WORKSPACE}:/home/ubuntu/workspace"
  -v "${HOST_CLAUDE_CONFIG_DIR}:${CONTAINER_CLAUDE_CONFIG_DIR}"
  -w /home/ubuntu/workspace
  -e "CLAUDE_CONFIG_DIR=${CONTAINER_CLAUDE_CONFIG_DIR}"
)

if [[ "${OFFLINE}" -eq 1 ]]; then
  docker_args+=(--network none)
fi

if [[ "${PASS_TOKEN}" -eq 1 ]]; then
  token="${GITHUB_TOKEN:-}"
  if [[ -z "${token}" ]] && command -v security >/dev/null 2>&1; then
    token="$(security find-generic-password -w -s "github" -a "token" 2>/dev/null || true)"
  fi
  if [[ -n "${token}" ]]; then
    docker_args+=(-e "GITHUB_TOKEN=${token}")
  fi
fi

claude_args=(claude)
if [[ "${PASS_YOLO}" -eq 1 ]]; then
  claude_args+=(--dangerously-skip-permissions)
fi

exec docker "${docker_args[@]}" "${IMAGE}" "${claude_args[@]}"
