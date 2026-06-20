#!/bin/bash
set -euo pipefail

SING="${SINGULARITY_BIN:-/opt/singularity-ce/4.3.0/bin/singularity}"
IMAGE="${QUOKKA_CLAUDE_IMAGE:-quokka-rocm-claude.sif}"
GHCR_IMAGE="docker://ghcr.io/chongchonghe/quokka-rocm-claude:latest"
LAUNCH_DIR="$(pwd)"
WORKSPACE_ARG=""

# The image installs Claude and user tools at /home/agent, but Singularity
# runs as the host UID and getpwuid(getuid()) returns the host user's home
# (e.g. /home/cche).  We bind host config files to the getpwuid home so
# ssh, git, gh and friends find them regardless of whether they consult
# $HOME or the password database.
AGENT_HOME="/home/agent"
CONTAINER_WORKSPACE="${AGENT_HOME}/workspace"
CONTAINER_CLAUDE_CONFIG_DIR="${AGENT_HOME}/superpowers/.claude"
HOST_CLAUDE_CONFIG_DIR="${QUOKKA_CLAUDE_CONFIG_DIR:-${HOME}/superpowers/.claude}"

# Singularity preserves the host UID, so getpwuid() inside the container
# returns the same home as ${HOME} on the host.  Use the host HOME directly
# (getent may not work depending on the host's NSS configuration).
PW_HOME="${HOME}"

PASS_TOKEN=0
OFFLINE=0
USE_DEEPSEEK=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--ds] [--pass-gh-token] [--offline] <workspace-dir>

Start a shell inside the Quokka ROCm+Claude Singularity container.
If ${IMAGE} is absent it is pulled from GHCR automatically (no root needed).

Arguments:
  workspace-dir  Directory to mount at ${CONTAINER_WORKSPACE}.

Options:
  --ds             Use DeepSeek's Anthropic-compatible API instead of Claude.
  --pass-gh-token  Pass GITHUB_TOKEN into the container.
  --offline        Disable container networking.

Environment:
  QUOKKA_CLAUDE_IMAGE       Singularity image to run (default: ${IMAGE})
  QUOKKA_CLAUDE_CONFIG_DIR  Host Claude config dir  (default: ${HOST_CLAUDE_CONFIG_DIR})
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
  echo "ERROR: Workspace directory does not exist: ${WORKSPACE}" >&2
  echo "       Create it first or pass an existing directory." >&2
  exit 1
fi

echo "==> Quokka ROCm + Claude (Singularity)" >&2
echo "==> Image: ${IMAGE}  |  pw-home: ${PW_HOME}  |  workspace: ${WORKSPACE}" >&2

# Pull from GHCR if the .sif is absent — no root required.
if [[ ! -f "${IMAGE}" ]]; then
  echo "==> Image not found: ${IMAGE}" >&2
  echo "==> Pulling from ${GHCR_IMAGE} ..." >&2
  "${SING}" pull "${IMAGE}" "${GHCR_IMAGE}" || {
    echo "ERROR: Failed to pull image from ${GHCR_IMAGE}" >&2
    exit 1
  }
  echo "==> Pull complete." >&2
fi

mkdir -p "${HOST_CLAUDE_CONFIG_DIR}"

# Build the bash init file.  We set HOME to the getpwuid home so $HOME
# and the password database agree.  PATH still includes /home/agent/...
# so Claude and other container-installed tools are found.
INITFILE=$(mktemp /tmp/singularity-bash-init-XXXXXX.sh)
trap 'rm -f "${INITFILE}"' EXIT
cat > "${INITFILE}" << INITEOF
export HOME="${PW_HOME}"
export PATH="${AGENT_HOME}/.local/bin:${AGENT_HOME}/.claude/local:${PW_HOME}/superpowers/quokka/bin:${AGENT_HOME}/superpowers/quokka/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PIP_BREAK_SYSTEM_PACKAGES=1
[[ -f /etc/bash.bashrc ]] && source /etc/bash.bashrc 2>/dev/null || true
# Re-assert after bash.bashrc / profile.d may have reset PATH
export HOME="${PW_HOME}"
export PATH="${AGENT_HOME}/.local/bin:${AGENT_HOME}/.claude/local:${PW_HOME}/superpowers/quokka/bin:${AGENT_HOME}/superpowers/quokka/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
INITEOF

sing_args=(
  exec
  --rocm
  --no-home
  --bind "${WORKSPACE}:${CONTAINER_WORKSPACE}"
  --pwd "${CONTAINER_WORKSPACE}"
  --env "CLAUDE_CONFIG_DIR=${CONTAINER_CLAUDE_CONFIG_DIR}"
  --env "claudeyolo=claude --dangerously-skip-permissions"
)

# ── Bind host config into the getpwuid home ──────────────────────────
# Because ssh, git, and others can use getpwuid(getuid())->pw_dir instead
# of $HOME, bind host dotfiles to the path that getpwuid actually returns.
# --bind creates missing parent directories, so ${PW_HOME} is created even
# though --no-home is set.
HOST_CONFIG_COUNT=0

[[ -d "${HOME}/superpowers" ]] && {
  sing_args+=(--bind "${HOME}/superpowers:${PW_HOME}/superpowers")
  HOST_CONFIG_COUNT=$((HOST_CONFIG_COUNT + 1))
}

# Git configuration
[[ -f "${HOME}/.gitconfig" ]] && {
  sing_args+=(--bind "${HOME}/.gitconfig:${PW_HOME}/.gitconfig")
  HOST_CONFIG_COUNT=$((HOST_CONFIG_COUNT + 1))
}
[[ -f "${HOME}/.git-credentials" ]] && {
  sing_args+=(--bind "${HOME}/.git-credentials:${PW_HOME}/.git-credentials:ro")
  HOST_CONFIG_COUNT=$((HOST_CONFIG_COUNT + 1))
}
[[ -d "${HOME}/.config/git" ]] && {
  sing_args+=(--bind "${HOME}/.config/git:${PW_HOME}/.config/git")
  HOST_CONFIG_COUNT=$((HOST_CONFIG_COUNT + 1))
}

# SSH keys (writable: ssh needs to update known_hosts for new hosts).
# Bind to both PW_HOME (for the new image where ssh uses the default
# ~/.ssh path) and AGENT_HOME (transitional: older images that hardcode
# /home/agent/.ssh/known_hosts in ssh_config).  Remove the AGENT_HOME
# bind once the updated image is in use.
[[ -d "${HOME}/.ssh" ]] && {
  sing_args+=(--bind "${HOME}/.ssh:${PW_HOME}/.ssh")
  sing_args+=(--bind "${HOME}/.ssh:${AGENT_HOME}/.ssh")
  HOST_CONFIG_COUNT=$((HOST_CONFIG_COUNT + 1))
}

# GitHub CLI
[[ -d "${HOME}/.config/gh" ]] && {
  sing_args+=(--bind "${HOME}/.config/gh:${PW_HOME}/.config/gh")
  HOST_CONFIG_COUNT=$((HOST_CONFIG_COUNT + 1))
}

echo "==> Mounted ${HOST_CONFIG_COUNT} host config(s) to ${PW_HOME}" >&2

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
sing_rc=$?
if [[ ${sing_rc} -ne 0 ]]; then
  echo "ERROR: Singularity exited with code ${sing_rc}" >&2
fi
exit ${sing_rc}
