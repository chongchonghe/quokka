#export GHCR_USER="chongchonghe"      # your GitHub username
#export GHCR_TOKEN="ghp_..."          # the classic PAT you just made for containers
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

docker build --platform linux/amd64 -t quokka-linux-amd64-rocm-claude-codex:development .
docker tag quokka-linux-amd64-rocm-claude-codex:development ghcr.io/quokka-astro/quokka-linux-amd64-rocm-claude-codex:development 
docker push ghcr.io/quokka-astro/quokka-linux-amd64-rocm-claude-codex:development 

