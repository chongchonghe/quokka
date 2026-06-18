#export GHCR_USER="chongchonghe"      # your GitHub username
#export GHCR_TOKEN="ghp_..."          # the classic PAT you just made for containers
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

export DOCKER_BUILDKIT=1
docker buildx create --use

docker buildx build --platform linux/amd64 \
  -t ghcr.io/quokka-astro/quokka-linux-amd64-rocm-claude-codex:development \
  -f ./Dockerfile \
  --push .

