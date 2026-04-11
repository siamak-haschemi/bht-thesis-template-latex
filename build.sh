#!/usr/bin/env bash
set -euo pipefail

# python3 software/drawio-svg-export/export-drawio-svg.py software/drawio-svg-export/figures.drawio

IMAGE="bht-thesis-texlive:latest"

bash scripts/check-abbreviations.sh

docker build --platform linux/amd64 -t "$IMAGE" -f Dockerfile . >/dev/null

docker run --rm --platform linux/amd64 \
  -v "$(pwd)":/workdir \
  -w /workdir \
  "$IMAGE" \
  latexmk -shell-escape -output-directory="./out" -pdf main.tex

bash scripts/check-build-log.sh out/main.log
