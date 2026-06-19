#!/bin/bash

# convert docker into singularity
if [ ! -e quokka-rocm-claude.sif ]; then
	if [ ! -e quokka-rocm-claude.tar ]; then
		exit 1
	fi
	singularity build quokka-rocm-claude.sif docker-archive://quokka-rocm-claude.tar
fi

echo "========== Running on $(date) =========="

set -e

sing="/opt/singularity-ce/4.3.0/bin/singularity"

#sif="quokka-linux-amd64-rocm-claude-codex.sif"
sif="quokka-rocm-claude.sif"
#if [ ! -f "$sif" ]; then
#  $sing pull "$sif" docker://ghcr.io/chongchonghe/quokka-linux-amd64-rocm-claude-codex:development
#fi

pwd

TARGET=/priv/avatar/cche/azp-agent-in-docker-moth/container-quokka-agents

$sing exec --rocm \
    --no-home \
    --bind $TARGET:$TARGET \
    --pwd $TARGET \
    $sif bash

