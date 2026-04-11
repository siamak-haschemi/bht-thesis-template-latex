#!/usr/bin/env bash
#
# CI build entrypoint. Builds the thesis PDF using Docker buildx with the
# GitHub Actions cache backend, then runs latexmk inside the resulting
# image. The local-dev counterpart is build.sh.
#
# Requires: docker, docker buildx, and (for caching) the
# ACTIONS_CACHE_URL / ACTIONS_RUNTIME_TOKEN env vars that
# docker/setup-buildx-action exports inside GitHub Actions runners.
#
set -euo pipefail

IMAGE="bht-thesis-texlive:latest"

bash scripts/check-abbreviations.sh

# --cache-{from,to} type=gha persists layers in GitHub's cache backend, so
# we don't re-pull texlive/texlive (~5 GB) and re-install inkscape on every
# CI run. mode=max stores intermediate layers too, not just the final one.
# --load copies the built image into the local docker image store so the
# subsequent `docker run` can find it (buildx doesn't load by default).
docker buildx build \
  --cache-from type=gha \
  --cache-to type=gha,mode=max \
  --load \
  -t "$IMAGE" \
  -f Dockerfile \
  .

docker run --rm \
  -v "$(pwd)":/workdir \
  -w /workdir \
  "$IMAGE" \
  latexmk -shell-escape -output-directory="./out" -pdf main.tex

bash scripts/check-build-log.sh out/main.log
