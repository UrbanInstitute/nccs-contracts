#!/usr/bin/env bash
# apply-branch-protection-baseline.sh — ADR 0047: require PRs + review on
# the default branch of every in-scope repo, plus the contracts-guard
# status check where the guard caller exists (no other checks mandated).
#
# Ruleset body: branch-protection-baseline.json (PRs required, 1 approving
# review with repository-admin bypass in pull_request mode -- admins
# self-merge but cannot skip PR flow; no deletions/force-pushes). On repos
# that carry the contracts-guard caller, the guard status check is appended
# as a required check (composing ADR 0022 step 4 into the same ruleset).
#
# Usage:
#   scripts/apply-branch-protection-baseline.sh            # dry-run
#   scripts/apply-branch-protection-baseline.sh --apply    # create/update
#   scripts/apply-branch-protection-baseline.sh owner/repo [...]  # override
#
# Requires: gh authed with admin on each target. `nccs` is deliberately
# absent (maintainer lacks admin there; see ADR 0047).
set -euo pipefail

ORG="UrbanInstitute"
RULESET_NAME="branch-protection-baseline"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BODY="${HERE}/branch-protection-baseline.json"
CALLER_PATH=".github/workflows/contracts-guard.yml"
GUARD_CONTEXT="contracts-guard / contracts-guard"

DEFAULT_REPOS=(
  "${ORG}/nccs-data-bmf" "${ORG}/nccs-data-core" "${ORG}/nccs-data-efile"
  "${ORG}/nccs-contracts" "${ORG}/nccsdata"
  "${ORG}/sector-in-brief-data" "${ORG}/sector-in-brief-api"
)

APPLY=false; REPOS=()
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) REPOS+=("$arg") ;;
  esac
done
[ ${#REPOS[@]} -eq 0 ] && REPOS=("${DEFAULT_REPOS[@]}")

for repo in "${REPOS[@]}"; do
  echo "== ${repo}"
  if [ "$(gh api "repos/${repo}" --jq .permissions.admin)" != "true" ]; then
    echo "   SKIP: not admin on ${repo}"; continue
  fi

  body="$(cat "${BODY}")"
  # Compose the guard check into the ruleset where the caller exists.
  if gh api "repos/${repo}/contents/${CALLER_PATH}" > /dev/null 2>&1; then
    body="$(printf '%s' "${body}" | python3 -c "
import json, sys
r = json.load(sys.stdin)
r['rules'].append({'type': 'required_status_checks', 'parameters': {
  'strict_required_status_checks_policy': False,
  'do_not_enforce_on_create': False,
  'required_status_checks': [{'context': '${GUARD_CONTEXT}'}]}})
print(json.dumps(r))")"
    echo "   guard caller present: contracts-guard check required"
  else
    echo "   no guard caller: PR/review/protection rules only"
  fi

  existing="$(gh api "repos/${repo}/rulesets" --jq \
    ".[] | select(.name == \"${RULESET_NAME}\") | .id" 2>/dev/null || true)"

  if ! $APPLY; then
    if [ -n "${existing}" ]; then
      echo "   DRY-RUN: would UPDATE ruleset id=${existing}"
    else
      echo "   DRY-RUN: would CREATE ruleset '${RULESET_NAME}'"
    fi
    continue
  fi

  if [ -n "${existing}" ]; then
    printf '%s' "${body}" | gh api -X PUT \
      "repos/${repo}/rulesets/${existing}" --input - > /dev/null
    echo "   UPDATED ruleset id=${existing}"
  else
    printf '%s' "${body}" | gh api -X POST \
      "repos/${repo}/rulesets" --input - > /dev/null
    echo "   CREATED ruleset '${RULESET_NAME}'"
  fi
done
