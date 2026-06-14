#!/usr/bin/env bash
#
# Pre-build sanity checks for abbreviations, in two directions:
#
#   1. Every \gls{key} / \glspl{key} / \glsentryshort{key} used in chapters/
#      or main.tex must have a matching \newacronym{key}{...}{...} in
#      abbreviations.tex. (Hard error — would break the LaTeX build anyway.)
#
#   2. Every abbreviation written as raw text (e.g. "HTTP" instead of
#      \gls{http}) must appear as a SHORT form in abbreviations.tex.
#
#   3. Abbreviations that ARE defined in abbreviations.tex but written as
#      raw text instead of \gls{key} (e.g. a literal "API" in prose) are
#      reported too, so first-use expansion and the page list stay correct.
#
# Checks 2 and 3 are heuristics (all-caps tokens in prose), so they only warn
# by default; run with CHECK_ABBR_STRICT=1 to turn warnings into errors.
# Known false positives go into the WHITELIST below.
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

TEX_FILES=(main.tex chapters/*.tex)

# Tokens that look like abbreviations but are fine without a glossary entry
# (Roman numerals, draft markers, table-internal column shortcuts, ...).
# Entries are matched as full regexes, e.g. TS[0-9]* covers TS, TS01, TS02, ...
WHITELIST="
II III IV VI VII VIII IX XI XII
TODO FIXME
TS[0-9]* FF[0-9]
MAX MIN US GB MB
"

# ---------------------------------------------------------------------------
# Check 1: every used \gls key is defined
# ---------------------------------------------------------------------------
defined_keys=$(grep -oE '\\(newacronym|newglossaryentry)\{[^}]+\}' "$ABBR_FILE" \
               | sed 's/.*{\([^}]*\)}.*/\1/' \
               | sort -u)

# matches \gls, \glspl, \Gls, \glsentryshort/long, \glsxtrshort/long/full, ...
used_keys=$(grep -rhoE '\\[gG]ls[a-zA-Z]*\{[^}]+\}' "${TEX_FILES[@]}" 2>/dev/null \
            | sed 's/.*{\([^}]*\)}/\1/' \
            | sort -u || true)

missing_keys=""
for key in $used_keys; do
  if ! echo "$defined_keys" | grep -qx "$key"; then
    missing_keys="$missing_keys $key"
  fi
done

if [ -n "$missing_keys" ]; then
  echo "❌ Undefined acronyms used in text:$missing_keys"
  echo
  echo "   Define them in $ABBR_FILE with:"
  echo "       \\newacronym{key}{SHORT}{Long form}"
  exit 1
fi

echo "✓ check-abbreviations: all \\gls{} keys are defined in $ABBR_FILE"

# ---------------------------------------------------------------------------
# Check 2: raw abbreviations in prose that are missing from the Verzeichnis
# ---------------------------------------------------------------------------
defined_shorts=$(grep -oE '\\newacronym\{[^}]+\}\{[^}]+\}' "$ABBR_FILE" \
                 | sed 's/\\newacronym{[^}]*}{\([^}]*\)}/\1/' \
                 | sort -u)

wl_regex=$(echo $WHITELIST | tr ' ' '|')

# Strip comments, verbatim-like environments and non-prose macro arguments
# (\cite, \label, \url, ...), then collect every remaining all-caps token
# (2+ letters, optional digits/hyphens, e.g. HTTP, UTF-8) as file:line:token.
# LC_ALL=C: process bytes, not multibyte chars — works around a macOS BSD awk
# bug ("towc: multibyte conversion failure") on UTF-8 input under a *.UTF-8
# locale. The äöüß byte sequences in the regexes below still match correctly.
candidates=$(LC_ALL=C awk '
  FNR == 1 { skip = 0; dmath = 0 }   # state must not leak across files
  /\\begin\{(verbatim|lstlisting|minted|filecontents|equation|align|gather|multline|eqnarray|math|displaymath)/ { skip = 1 }
  /\\end\{(verbatim|lstlisting|minted|filecontents|equation|align|gather|multline|eqnarray|math|displaymath)/   { skip = 0; next }
  skip { next }
  {
    line = $0
    # drop comments, but keep escaped \%
    gsub(/\\%/, "\x01", line)
    sub(/%.*/, "", line)
    gsub(/\x01/, " ", line)
    # line breaks like \\[4pt] must not look like display math \[
    gsub(/\\\\(\[[^]]*\])?/, " ", line)
    # drop math mode: \mathrm{MAE} etc. are symbols, not abbreviation usage
    if (dmath) {                              # inside multi-line \[ ... \]
      if (line ~ /\\\]/) { sub(/.*\\\]/, " ", line); dmath = 0 }
      else next
    }
    gsub(/\\\[[^]]*\\\]/, " ", line)          # single-line \[ ... \]
    if (line ~ /\\\[/) { sub(/\\\[.*/, " ", line); dmath = 1 }
    gsub(/\\\$/, "\x02", line)                # protect literal \$
    gsub(/\$[^$]*\$/, " ", line)              # inline $ ... $
    gsub(/\\\(.*\\\)/, " ", line)             # inline \( ... \)
    gsub(/\x02/, " ", line)
    # drop arguments of macros whose content is not prose
    gsub(/\\(no)?[a-zA-Z]*cite[a-zA-Z]*(\[[^]]*\])*\{[^}]*\}/, " ", line)
    gsub(/\\(label|ref|cref|Cref|vref|pageref|nameref|url|hyperref|input|include|includegraphics|includesvg|includepdf|[gG]ls[a-zA-Z]*|bibliography|addbibresource|graphicspath|lstinputlisting|verb)(\[[^]]*\])*\{[^}]*\}/, " ", line)
    # \texorpdfstring{<typeset>}{<pdf-string>}: the 2nd arg is a plain-text copy
    # of the heading/caption for the PDF bookmark, not independent prose. The
    # gls content in the 1st arg has already been stripped just above, so drop
    # the whole macro to avoid double-counting the fallback text (e.g. the "API"
    # in \texorpdfstring{\glsentryshort{api}}{API}).
    gsub(/\\texorpdfstring\{[^{}]*\}\{[^{}]*\}/, " ", line)
    gsub(/\\href\{[^}]*\}/, " ", line)
    gsub(/\\(texttt|lstinline|path|detokenize)\{[^}]*\}/, " ", line)
    gsub(/\\(begin|end)\{[^}]*\}/, " ", line)
    # drop remaining command names (\LaTeX, \TODO, ...)
    gsub(/\\[a-zA-Z@]+/, " ", line)
    while (match(line, /[A-Z][A-Z0-9]*(-[A-Z0-9]+)*/)) {
      tok   = substr(line, RSTART, RLENGTH)
      rest  = substr(line, RSTART + RLENGTH)
      prevc = (RSTART > 1) ? substr(line, RSTART - 1, 1) : " "
      line  = rest
      # capital run inside a mixed-case word (SQuaRE, PyPI): not an abbreviation
      if (prevc ~ /[a-zäöüß]/) continue
      c1 = substr(rest, 1, 1)
      c2 = substr(rest, 2, 1)
      # token runs into a lowercase letter (and is not a plural like "APIs"):
      # German compound "PDF-Dokument" -> keep "PDF"; CamelCase word like
      # "PSPDFKit" -> not an abbreviation at all, skip it
      if (c1 ~ /[a-zäöüß]/ && !(c1 == "s" && c2 !~ /[A-Za-zäöüß]/)) {
        if (tok ~ /-/) sub(/-[A-Z0-9]*$/, "", tok)
        else continue
      }
      if (tok ~ /[A-Z][A-Z0-9-]*[A-Z]/)   # at least two capital letters
        print FILENAME ":" FNR ":" tok
    }
  }
' "${TEX_FILES[@]}")

# "SHORT key" pairs, to suggest the right \gls{key} in check 3
short_to_key=$(grep -oE '\\newacronym\{[^}]+\}\{[^}]+\}' "$ABBR_FILE" \
               | sed 's/\\newacronym{\([^}]*\)}{\([^}]*\)}/\2 \1/')

print_locations() {  # $1 = token
  locations=$(echo "$candidates" | awk -F: -v t="$1" '$3 == t { print $1 ":" $2 }')
  count=$(echo "$locations" | wc -l)
  printf '   %-10s (%d×)  %s\n' "$1" "$count" "$(echo "$locations" | head -3 | paste -sd' ' -)"
}

unlisted=""   # raw abbreviation, no entry in abbreviations.tex     (check 2)
unmarked=""   # entry exists, but written raw instead of \gls{key}  (check 3)
for tok in $(echo "$candidates" | cut -d: -f3 | sort -u); do
  echo "$tok" | grep -qxE "($wl_regex)" && continue
  if echo "$defined_shorts" | grep -qxF "$tok"; then
    unmarked="$unmarked $tok"
  else
    unlisted="$unlisted $tok"
  fi
done

warned=0

if [ -n "$unlisted" ]; then
  warned=1
  echo
  echo "⚠️  Abbreviations used in text but missing from $ABBR_FILE:"
  for tok in $unlisted; do print_locations "$tok"; done
  echo
  echo "   Either add a \\newacronym{key}{SHORT}{Long form} to $ABBR_FILE and"
  echo "   use \\gls{key} in the text, or add false positives to the WHITELIST"
  echo "   in scripts/check-abbreviations.sh."
fi

if [ -n "$unmarked" ]; then
  warned=1
  echo
  echo "⚠️  Abbreviations defined in $ABBR_FILE but written without \\gls{}:"
  for tok in $unmarked; do
    key=$(echo "$short_to_key" | awk -v s="$tok" '$1 == s { print $2; exit }')
    print_locations "$tok" | sed "s/\$/   -> use \\\\gls{$key}/"
  done
fi

if [ "$warned" = "1" ]; then
  if [ "${CHECK_ABBR_STRICT:-0}" = "1" ]; then
    exit 1
  fi
else
  echo "✓ check-abbreviations: no unlisted or unmarked abbreviations found in text"
fi
