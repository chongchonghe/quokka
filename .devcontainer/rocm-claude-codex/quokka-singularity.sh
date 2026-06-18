#!/bin/bash

echo "========== Running on $(date) =========="

set -e

sing="/opt/singularity-ce/4.3.0/bin/singularity"

sif="quokka-linux-amd64-rocm-claude-codex.sif"
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

