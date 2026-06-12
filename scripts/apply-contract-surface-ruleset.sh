#!/usr/bin/env bash
# apply-contract-surface-ruleset.sh — make the contracts-guard check NON-OPTIONAL
# on the in-scope repos, via a per-repo GitHub ruleset (ADR 0022, step 4 amended).
#
# The reusable guard (ADR 0022) already *runs* in every in-scope repo as a thin
# caller. Running it does not make it REQUIRED — a PR can still merge red. The
# original plan made it required with an org-wide ruleset keyed on a
# `contract-surface=true` property, which needs org-owner rights the maintainer
# does not have. This applies the documented fallback instead: a per-repo ruleset
# (admin-only, no org-owner needed) that requires the `contracts-guard /
# contracts-guard` status check on the default branch.
#
# Relief valve is the guard's OWN escape hatch — a `contracts-ack` label or an
# `ADR NNNN` breadcrumb flips the check green — so the ruleset carries NO bypass
# actors. Break-glass = temporarily set the ruleset `enforcement` to "disabled".
#
# Usage:
#   scripts/apply-contract-surface-ruleset.sh            # dry-run over the default repos
#   scripts/apply-contract-surface-ruleset.sh --apply    # actually create/update
#   scripts/apply-contract-surface-ruleset.sh owner/repo [owner/repo ...]   # override targets
#
# Requires: gh (authed, admin on each target repo). The token needs the `repo`
# scope; creating a ruleset needs ADMIN on the repo.
set -euo pipefail

ORG="UrbanInstitute"
RULESET_NAME="contract-surface-guard"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BODY="${HERE}/contract-surface-ruleset.json"
CALLER_PATH=".github/workflows/contracts-guard.yml"

# Default targets = repos where the maintainer is confirmed admin (memory /
# ADR 0022 line 86). Verify admin on the rest before adding them here.
#   confirmed admin: nccs-data-core, nccs-data-bmf
# NOT included by default — verify admin first, and only once they carry the
# guard caller: nccsdata, sector-in-brief, sector-in-brief-data,
# nccs-data-efile, nccs. EXCLUDED until its caller lands: sector-in-brief-api.
DEFAULT_REPOS=("${ORG}/nccs-data-core" "${ORG}/nccs-data-bmf")

APPLY=false
REPOS=()
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) REPOS+=("$arg") ;;
  esac
done
[ ${#REPOS[@]} -eq 0 ] && REPOS=("${DEFAULT_REPOS[@]}")

$APPLY || echo "DRY-RUN (no changes). Re-run with --apply to create/update rulesets."
echo

for repo in "${REPOS[@]}"; do
  echo "=== ${repo} ==="

  # Admin precondition — creating a ruleset requires admin; fail loud, not silent.
  perm="$(gh api "repos/${repo}" -q '.permissions.admin' 2>/dev/null || echo "ERR")"
  if [ "$perm" != "true" ]; then
    echo "  SKIP — no admin (permissions.admin=${perm}). Ruleset creation needs admin." ; echo ; continue
  fi

  # Completeness check (Principle 5): a required check that never runs would
  # block EVERY merge. Refuse to require the guard on a repo that lacks the caller.
  if ! gh api "repos/${repo}/contents/${CALLER_PATH}" -q '.path' >/dev/null 2>&1; then
    echo "  SKIP — no guard caller at ${CALLER_PATH}; requiring it would block all merges." ; echo ; continue
  fi

  existing_id="$(gh api "repos/${repo}/rulesets" -q ".[] | select(.name==\"${RULESET_NAME}\") | .id" 2>/dev/null || true)"

  if [ -n "$existing_id" ]; then
    echo "  ruleset '${RULESET_NAME}' exists (id ${existing_id}) -> UPDATE"
    if $APPLY; then
      gh api --method PUT "repos/${repo}/rulesets/${existing_id}" --input "$BODY" -q '.enforcement' \
        | sed 's/^/  enforcement now: /'
    fi
  else
    echo "  ruleset '${RULESET_NAME}' absent -> CREATE (require 'contracts-guard / contracts-guard')"
    if $APPLY; then
      gh api --method POST "repos/${repo}/rulesets" --input "$BODY" -q '.id' \
        | sed 's/^/  created ruleset id: /'
    fi
  fi
  echo
done

$APPLY || echo "DRY-RUN complete. No rulesets were created or modified."
