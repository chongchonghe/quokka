#!/bin/bash
set -euo pipefail

SING="${SINGULARITY_BIN:-/opt/singularity-ce/4.3.0/bin/singularity}"
IMAGE="${QUOKKA_CLAUDE_IMAGE:-quokka-rocm-claude.sif}"
GHCR_IMAGE="docker://ghcr.io/chongchonghe/quokka-rocm-claude:latest"
LAUNCH_DIR="$(pwd)"
WORKSPACE_ARG=""
# Claude config dir on the host; defaults to .claude/ in the launch directory
# so each workspace can carry its own auth/settings.
HOST_CLAUDE_CONFIG_DIR="${QUOKKA_CLAUDE_CONFIG_DIR:-${LAUNCH_DIR}/.claude}"
# The image was built with an 'agent' user at /home/agent; all container-side
# paths use that home so tools find their config even when Singularity runs as
# the host UID.
CONTAINER_HOME="/home/agent"
CONTAINER_CLAUDE_CONFIG_DIR="${CONTAINER_HOME}/.claude"

PASS_TOKEN=0
OFFLINE=0
USE_DEEPSEEK=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--ds] [--pass-gh-token] [--offline] <workspace-dir>

Start a shell inside the Quokka ROCm+Claude Singularity container.
If ${IMAGE} is absent it is pulled from GHCR automatically (no root needed).

Arguments:
  workspace-dir  Directory to mount at ${CONTAINER_HOME}/workspace.

Options:
  --ds             Use DeepSeek's Anthropic-compatible API instead of Claude.
  --pass-gh-token  Pass GITHUB_TOKEN into the container.
  --offline        Disable container networking.

Environment:
  QUOKKA_CLAUDE_IMAGE       Singularity image to run (default: ${IMAGE})
  QUOKKA_CLAUDE_CONFIG_DIR  Host Claude config dir  (default: <launch-dir>/.claude)
  SINGULARITY_BIN           Path to singularity binary (default: ${SING})
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ds)           USE_DEEPSEEK=1 ;;
    --pass-gh-token) PASS_TOKEN=1 ;;
    --offline)      OFFLINE=1 ;;
    -h|--help)      usage; exit 0 ;;
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
[[ "${WORKSPACE}" != /* ]] && WORKSPACE="${LAUNCH_DIR}/${WORKSPACE}"

if [[ ! -d "${WORKSPACE}" ]]; then
  echo "Workspace directory does not exist: ${WORKSPACE}" >&2
  exit 1
fi

# Pull from GHCR if the .sif is absent — no root required.
if [[ ! -f "${IMAGE}" ]]; then
  echo "Image not found: ${IMAGE}" >&2
  echo "Pulling from ${GHCR_IMAGE} ..." >&2
  "${SING}" pull "${IMAGE}" "${GHCR_IMAGE}"
fi

mkdir -p "${HOST_CLAUDE_CONFIG_DIR}"

# The container's /etc/bash.bashrc sources profile.d scripts that reset PATH.
# Use bash --init-file with a temp file that re-asserts PATH after sourcing
# system bashrc, so completions and aliases are preserved.
INITFILE=$(mktemp /tmp/singularity-bash-init-XXXXXX.sh)
trap 'rm -f "${INITFILE}"' EXIT
cat > "${INITFILE}" << 'INITEOF'
export PATH="/home/agent/.local/bin:/home/agent/.claude/local:/home/agent/superpowers/quokka/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PIP_BREAK_SYSTEM_PACKAGES=1
[[ -f /etc/bash.bashrc ]] && source /etc/bash.bashrc 2>/dev/null || true
# Re-assert after bash.bashrc / profile.d may have reset PATH
export PATH="/home/agent/.local/bin:/home/agent/.claude/local:/home/agent/superpowers/quokka/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
INITEOF

sing_args=(
  exec
  --rocm
  --no-home
  --bind "${WORKSPACE}:${CONTAINER_HOME}/workspace"
  --bind "${HOST_CLAUDE_CONFIG_DIR}:${CONTAINER_CLAUDE_CONFIG_DIR}"
  --pwd "${CONTAINER_HOME}/workspace"
  # Set HOME so tools that read $HOME (ssh, gh, git) find the right directories.
  --env "HOME=${CONTAINER_HOME}"
  --env "CLAUDE_CONFIG_DIR=${CONTAINER_CLAUDE_CONFIG_DIR}"
  --env "claudeyolo=claude --dangerously-skip-permissions"
)

# Optional bind mounts — skip silently if the source doesn't exist on this host.
[[ -d "${HOME}/superpowers/quokka" ]] && \
  sing_args+=(--bind "${HOME}/superpowers/quokka:${CONTAINER_HOME}/superpowers/quokka")
[[ -d "${HOME}/.ssh" ]] && \
  sing_args+=(--bind "${HOME}/.ssh:${CONTAINER_HOME}/.ssh:ro")
[[ -d "${HOME}/.config/gh" ]] && \
  sing_args+=(--bind "${HOME}/.config/gh:${CONTAINER_HOME}/.config/gh")

if [[ "${OFFLINE}" -eq 1 ]]; then
  sing_args+=(--net --network none)
fi

if [[ "${PASS_TOKEN}" -eq 1 ]]; then
  token="${GITHUB_TOKEN:-}"
  if [[ -z "${token}" ]] && command -v security >/dev/null 2>&1; then
    token="$(security find-generic-password -w -s "github" -a "pr-and-issue" 2>/dev/null || true)"
  fi
  [[ -n "${token}" ]] && sing_args+=(--env "GITHUB_TOKEN=${token}")
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
  sing_args+=(
    --env "DEEPSEEK_API_KEY=${deepseek_api_key}"
    --env "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
    --env "ANTHROPIC_AUTH_TOKEN=${deepseek_api_key}"
    --env "API_TIMEOUT_MS=3000000"
    --env "ANTHROPIC_MODEL=deepseek-v4-pro[1m]"
    --env "ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro"
    --env "ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro"
    --env "ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash"
    --env "CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-pro"
    --env "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
    --env "CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK=1"
    --env "CLAUDE_CODE_EFFORT_LEVEL=max"
  )
fi

"${SING}" "${sing_args[@]}" "${IMAGE}" bash --init-file "${INITFILE}"
