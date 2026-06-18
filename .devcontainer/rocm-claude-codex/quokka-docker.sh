#!/bin/bash
set -euo pipefail

IMAGE="${QUOKKA_CLAUDE_IMAGE:-quokka-linux-amd64-rocm-claude-codex}"
LAUNCH_DIR="$(pwd)"
WORKSPACE_ARG=""
HOST_CLAUDE_CONFIG_DIR="${QUOKKA_CLAUDE_CONFIG_DIR:-${LAUNCH_DIR}/.claude}"
CONTAINER_CLAUDE_CONFIG_DIR="/home/ubuntu/.claude"

PASS_TOKEN=0
OFFLINE=0
USE_DEEPSEEK=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--ds] [--pass-gh-token] [--offline] <workspace-dir>

Start a shell inside a Quokka CUDA Docker container.

Arguments:
  workspace-dir  Directory to mount at /home/ubuntu/workspace.

Options:
  --ds             Use DeepSeek's Anthropic-compatible API for Claude.
  --pass-gh-token  Pass GITHUB_TOKEN into the container.
  --offline        Disable container networking.

Environment:
  QUOKKA_CLAUDE_IMAGE       Docker image to run (default: ${IMAGE})
  QUOKKA_CLAUDE_CONFIG_DIR  Host Claude config dir (default: ${HOST_CLAUDE_CONFIG_DIR})
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ds)
      USE_DEEPSEEK=1
      ;;
    --pass-gh-token)
      PASS_TOKEN=1
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
  -v "${HOME}/superpowers/quokka:/home/ubuntu/superpowers/quokka"
  -v ~/.ssh:/home/ubuntu/.ssh:ro
  -v "${HOME}/.config/gh:/home/ubuntu/.config/gh"
  -w /home/ubuntu/workspace
  -e "CLAUDE_CONFIG_DIR=${CONTAINER_CLAUDE_CONFIG_DIR}"
  -e "claudeyolo=claude --dangerously-skip-permissions"
)

if [[ "${OFFLINE}" -eq 1 ]]; then
  docker_args+=(--network none)
fi

if [[ "${PASS_TOKEN}" -eq 1 ]]; then
  token="${GITHUB_TOKEN:-}"
  if [[ -z "${token}" ]] && command -v security >/dev/null 2>&1; then
    token="$(security find-generic-password -w -s "github" -a "pr-and-issue" 2>/dev/null || true)"
  fi
  if [[ -n "${token}" ]]; then
    docker_args+=(-e "GITHUB_TOKEN=${token}")
  fi
fi

if [[ "${USE_DEEPSEEK}" -eq 1 ]]; then
  deepseek_api_key="${DEEPSEEK_API_KEY:-}"
  if [[ -z "${deepseek_api_key}" ]] && command -v security >/dev/null 2>&1; then
    deepseek_api_key="$(security find-generic-password -w -s "deepseek-api" -a "api-key" 2>/dev/null || true)"
  fi
  if [[ -z "${deepseek_api_key}" ]]; then
    echo "DeepSeek API key not found. Set DEEPSEEK_API_KEY or store it in Keychain as service 'deepseek-api', account 'api-key'." >&2
    exit 1
  fi

  docker_args+=(
    -e "DEEPSEEK_API_KEY=${deepseek_api_key}"
    -e "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
    -e "ANTHROPIC_AUTH_TOKEN=${deepseek_api_key}"
    -e "API_TIMEOUT_MS=3000000"
    -e "ANTHROPIC_MODEL=deepseek-v4-pro[1m]"
    -e "ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro"
    -e "ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro"
    -e "ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash"
    -e "CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-pro"
    -e "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
    -e "CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK=1"
    -e "CLAUDE_CODE_EFFORT_LEVEL=max"
  )
fi

exec docker "${docker_args[@]}" "${IMAGE}" bash
