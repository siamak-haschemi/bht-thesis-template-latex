#!/usr/bin/env bash
#
# Post-build sanity check: scan the LaTeX log for the warnings latexmk
# silently ignores. Catches the things students actually break (broken
# \cref/\ref, missing \cite, duplicate labels, missing \gls keys, missing
# rerun) and turns them into a non-zero exit so CI and local builds fail
# loudly instead of producing a half-broken PDF.
#
# Usage: bash scripts/check-build-log.sh [path/to/main.log]
# Default log path is out/main.log (matches build.sh).
#
set -euo pipefail

cd "$(dirname "$0")/.."

LOG="${1:-out/main.log}"
if [ ! -f "$LOG" ]; then
  echo "❌ check-build-log: $LOG not found"
  exit 1
fi

fail=0

check() {
  local label="$1" pattern="$2"
  local hits
  hits=$(grep -E "$pattern" "$LOG" || true)
  if [ -n "$hits" ]; then
    echo "❌ $label:"
    echo "$hits" | sed 's/^/   /' | head -20
    fail=1
  fi
}

check "Undefined references"     'LaTeX Warning: Reference .* undefined'
check "Undefined citations"      'LaTeX Warning: Citation .* undefined'
check "Multiply-defined labels"  'LaTeX Warning: (Label .* multiply defined|There were multiply-defined labels)'
check "Missing glossary entries" 'Glossary entry .* has not been defined'
check "Rerun needed"             'Rerun to get .* right'

if [ "$fail" -ne 0 ]; then
  echo
  echo "❌ check-build-log: $LOG contains issues — fix them before committing."
  exit 1
fi

echo "✓ check-build-log: no issues found in $LOG"
