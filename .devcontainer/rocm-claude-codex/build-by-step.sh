docker build --platform linux/amd64 -t quokka-linux-amd64-rocm-claude-codex:development .
docker tag quokka-linux-amd64-rocm-claude-codex:development ghcr.io/quokka-astro/quokka-linux-amd64-rocm-claude-codex:development 
docker push ghcr.io/quokka-astro/quokka-linux-amd64-rocm-claude-codex:development 

