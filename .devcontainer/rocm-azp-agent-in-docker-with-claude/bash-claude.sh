#!/bin/bash
set -euo pipefail

sing="/opt/singularity-ce/4.3.0/bin/singularity"
sif="quokka-rocm-claude.sif"
GHCR_IMAGE="docker://ghcr.io/chongchonghe/quokka-rocm-claude:latest"

if [ ! -e "$sif" ]; then
	if [ -e quokka-rocm-claude.tar ]; then
		# Convert from a locally-built Docker archive.
		# Prefer the .def file when present: it writes PATH into profile.d so it
		# survives shell startup scripts.
		if [ -e quokka-rocm-claude.def ]; then
			$sing build --fakeroot "$sif" quokka-rocm-claude.def
		else
			$sing build "$sif" docker-archive://quokka-rocm-claude.tar
		fi
	else
		# Pull from GHCR (no root needed). The image is ~5 GB; retry up to 3
		# times in case of transient network errors.
		MAX_RETRIES=3
		for attempt in $(seq 1 $MAX_RETRIES); do
			if $sing pull "$sif" "$GHCR_IMAGE"; then
				break
			fi
			echo "Pull failed (attempt ${attempt}/${MAX_RETRIES})" >&2
			rm -f "$sif"
			if [ "$attempt" -eq "$MAX_RETRIES" ]; then
				echo "All pull attempts failed. Check your network connection." >&2
				exit 1
			fi
			echo "Retrying in 10 seconds..." >&2
			sleep 10
		done
	fi
fi

echo "========== Running on $(date) =========="
pwd

TARGET=/priv/avatar/cche/azp-agent-in-docker-moth/container-quokka-agents

# Singularity --env is overridden by the container's /etc/bash.bashrc, which
# sources /etc/profile.d/ scripts that reset PATH.  Work around this by
# creating a bash init file in /tmp (mounted from the host into the container)
# that (1) sources system bashrc for completions, then (2) re-asserts PATH.
INITFILE=$(mktemp /tmp/singularity-bash-init-XXXXXX.sh)
trap "rm -f '${INITFILE}'" EXIT
cat > "$INITFILE" << 'INITEOF'
export HOME="/home/agent"
export PATH="/home/agent/.local/bin:/home/agent/.claude/local:/home/agent/superpowers/quokka/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PIP_BREAK_SYSTEM_PACKAGES=1
[[ -f /etc/bash.bashrc ]] && source /etc/bash.bashrc 2>/dev/null || true
# Re-assert after bash.bashrc may have reset PATH via profile.d
export HOME="/home/agent"
export PATH="/home/agent/.local/bin:/home/agent/.claude/local:/home/agent/superpowers/quokka/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
INITEOF

$sing exec --rocm \
    --no-home \
    --bind "$TARGET:$TARGET" \
    --pwd "$TARGET" \
    "$sif" bash --init-file "$INITFILE"
