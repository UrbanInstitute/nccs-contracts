#!/usr/bin/env bash
# Generate the ADR index table (book/_adr-index.md) from decisions/*.md.
# Pure shell — no R/knitr — so the Quarto/Pages build needs only Quarto itself.
# Run from anywhere; resolves the repo root relative to this script.
set -euo pipefail

cd "$(dirname "$0")/.."   # repo root
OUT="book/_adr-index.md"
BLOB="https://github.com/UrbanInstitute/nccs-contracts/blob/main"

{
  echo "| ADR | Title | Status |"
  echo "|:---:|-------|--------|"
  for f in decisions/[0-9]*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    num="${base%%-*}"

    # Title: first H1, strip leading '# ' and any leading 'NNNN — ' / 'NNNN -- '.
    title="$(grep -m1 '^# ' "$f" | sed -E 's/^#[[:space:]]*//; s/^[0-9]+[[:space:]]*[—-]+[[:space:]]*//')"
    # Escape pipes so a stray '|' in a title can't break the table.
    title="${title//|/\\|}"

    # Status: leading canonical token of the Status line (first word).
    status="$(grep -m1 '^- \*\*Status:\*\*' "$f" \
      | sed -E 's/^- \*\*Status:\*\*[[:space:]]*//; s/[[:space:]].*$//')"
    [ -n "$status" ] || status="—"

    printf '| [%s](%s/%s) | %s | %s |\n' "$num" "$BLOB" "$f" "$title" "$status"
  done
} > "$OUT"

echo "wrote $OUT ($(grep -c '^| \[' "$OUT") ADRs)"
