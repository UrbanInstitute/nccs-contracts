#!/usr/bin/env bash
#
# reconcile.sh — surface in-repo decisions that may not yet be reflected in
# nccs-contracts. The companion to each sibling repo's `contracts-guard.yml`:
# the guard nags at PR time; this finds what already slipped through.
#
# Two modes:
#
#   scripts/reconcile.sh 0021         Show every commit across sibling repos
#                                     that references "ADR 0021" — i.e. what was
#                                     actually executed for that decision. Use
#                                     this when reconciling one ADR.
#
#   scripts/reconcile.sh              AUDIT: for each sibling repo, list recent
#                                     commits that touch contract-relevant paths
#                                     but carry NO `ADR NNNN` breadcrumb — the
#                                     candidate un-reconciled decisions to chase.
#
# Config (env):
#   SIBLINGS  Space-separated repo paths. Default: every git repo one level up
#             from this one (../*), excluding this repo.
#   SINCE     Lookback window for the audit. Default: "3 weeks ago".
#
# No deps beyond git + grep. Read-only; never writes or fetches.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT="$(dirname "$REPO_ROOT")"
SELF="$(basename "$REPO_ROOT")"
SINCE="${SINCE:-3 weeks ago}"
ADR_RE='ADR[ -]?[0-9]{3,4}'

# Contract-relevant path regex per repo (keep in sync with each repo's
# contracts-guard.yml PATHS_REGEX). Default catches common publish/schema code.
paths_regex_for() {
  case "$1" in
    nccs-data-bmf)
      echo '^(R/publish_.*\.R|R/run_.*\.R|R/master_.*\.R|R/config\.R|R/manifest\.R|scripts/build_.*\.R)$' ;;
    sector-in-brief-data)
      echo '^(R/publish\.R|R/config\.R|R/manifest\.R|R/build_.*\.R|R/data_dictionary_curation\.R|R/panel_.*\.R|R/read_.*\.R|config\.yml)$' ;;
    *)
      echo '^(R/publish.*\.R|R/run_.*\.R|.*config\.(R|yml)|R/manifest\.R|scripts/build_.*\.R|.*publish.*\.(R|py|sh))$' ;;
  esac
}

# Resolve sibling repos.
if [ -n "${SIBLINGS:-}" ]; then
  SIBS="$SIBLINGS"
else
  SIBS=""
  for d in "$PARENT"/*/; do
    name="$(basename "$d")"
    [ "$name" = "$SELF" ] && continue
    [ -d "$d/.git" ] && SIBS="$SIBS $d"
  done
fi

if [ -z "${SIBS// /}" ]; then
  echo "No sibling git repos found under $PARENT (set SIBLINGS=... to override)." >&2
  exit 1
fi

# ---- Mode 1: breadcrumb lookup for one ADR -------------------------------
if [ "$#" -ge 1 ]; then
  NUM="$(printf '%s' "$1" | tr -cd '0-9')"
  [ -n "$NUM" ] || { echo "usage: reconcile.sh [ADR-number]" >&2; exit 2; }
  echo "Commits referencing ADR $NUM across sibling repos:"
  found=0
  for s in $SIBS; do
    out="$(git -C "$s" log --all --oneline -i --grep "ADR[ -]\?0*${NUM}\b" 2>/dev/null || true)"
    if [ -n "$out" ]; then
      found=1
      echo; echo "### $(basename "$s")"
      printf '%s\n' "$out" | sed 's/^/  /'
    fi
  done
  [ "$found" -eq 0 ] && echo "  (none — no ADR $NUM breadcrumbs found)"
  exit 0
fi

# ---- Mode 2: audit for un-reconciled contract-relevant commits -----------
echo "Audit: contract-relevant commits since \"$SINCE\" with NO ADR breadcrumb"
echo "(candidate un-reconciled decisions — verify against contracts/ + decisions/)"
any=0
for s in $SIBS; do
  name="$(basename "$s")"
  regex="$(paths_regex_for "$name")"
  hits=""
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    # Skip if the commit message already carries an ADR breadcrumb.
    msg="$(git -C "$s" log -1 --format='%B' "$sha" 2>/dev/null || true)"
    printf '%s' "$msg" | grep -qiE "$ADR_RE" && continue
    # Does it touch a contract-relevant path?
    files="$(git -C "$s" show --name-only --format='' "$sha" 2>/dev/null || true)"
    if printf '%s\n' "$files" | grep -qE "$regex"; then
      subj="$(git -C "$s" log -1 --format='%h %s' "$sha" 2>/dev/null || true)"
      hits="$hits  $subj"$'\n'
    fi
  done < <(git -C "$s" log --since="$SINCE" --format='%H' 2>/dev/null || true)

  if [ -n "$hits" ]; then
    any=1
    echo; echo "### $name"
    printf '%s' "$hits"
  fi
done
[ "$any" -eq 0 ] && echo "  (clean — no un-reconciled contract-relevant commits in the window)"
exit 0
