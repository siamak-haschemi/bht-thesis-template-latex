#!/usr/bin/env bash
set -euo pipefail

# Removes all build artifacts produced by build.sh.
# Does NOT touch figures/, cover/, chapters/, bib/ or the committed template.pdf.

cd "$(dirname "$0")"

# latexmk output directory (see build.sh)
rm -rf out

# svg package's Inkscape conversion cache (created at CWD by \includesvg)
rm -rf svg-inkscape

# Stray LaTeX intermediates if anything ever escapes the out/ dir
find . \
  -path ./figures -prune -o \
  -path ./cover -prune -o \
  -path ./.git -prune -o \
  \( \
    -name '*.aux' -o \
    -name '*.bbl' -o \
    -name '*.bcf' -o \
    -name '*.bcf-SAVE-ERROR' -o \
    -name '*.bbl-SAVE-ERROR' -o \
    -name '*.blg' -o \
    -name '*.fdb_latexmk' -o \
    -name '*.fls' -o \
    -name '*.log' -o \
    -name '*.lof' -o \
    -name '*.lot' -o \
    -name '*.out' -o \
    -name '*.toc' -o \
    -name '*.run.xml' -o \
    -name '*.synctex.gz' -o \
    -name '*.glo' -o \
    -name '*.gls' -o \
    -name '*.glg' -o \
    -name '*.acn' -o \
    -name '*.acr' -o \
    -name '*.alg' -o \
    -name '*.ist' -o \
    -name '*.xdy' -o \
    -name '.DS_Store' \
  \) -type f -print -delete
