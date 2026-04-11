#!/usr/bin/env bash
#
# Pre-build sanity check: every \gls{key} / \glspl{key} / \glsentryshort{key}
# used in chapters/ or main.tex must have a matching \newacronym{key}{...}{...}
# in abbreviations.tex. Fail fast and give a clear error so students don't have
# to dig through a 2000-line LaTeX log to find a typo.
#
# Run from the repo root: bash scripts/check-abbreviations.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

ABBR_FILE="abbreviations.tex"
if [ ! -f "$ABBR_FILE" ]; then
  echo "ℹ︎  $ABBR_FILE not found, skipping abbreviation check"
  exit 0
fi

defined=$(grep -oE '\\newacronym\{[^}]+\}' "$ABBR_FILE" \
          | sed 's/.*{\([^}]*\)}.*/\1/' \
          | sort -u)

used=$(grep -rhoE '\\gls(pl|entryshort)?\{[^}]+\}' chapters/ main.tex 2>/dev/null \
       | sed 's/.*{\([^}]*\)}/\1/' \
       | sort -u || true)

missing=""
for key in $used; do
  if ! echo "$defined" | grep -qx "$key"; then
    missing="$missing $key"
  fi
done

if [ -n "$missing" ]; then
  echo "❌ Undefined acronyms used in text:$missing"
  echo
  echo "   Define them in $ABBR_FILE with:"
  echo "       \\newacronym{key}{SHORT}{Long form}"
  exit 1
fi

echo "✓ check-abbreviations: all \\gls{} keys are defined in $ABBR_FILE"
