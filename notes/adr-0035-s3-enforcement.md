# ADR 0035 Follow-up 1 — S3 non-deletion enforcement for `harmonized/core/`

**Operator runbook.** Executes the technical half of ADR 0035: a bucket-policy `Deny`
on the frozen `harmonized/core/` prefix so the retained surface can't be silently
deleted. The contract (`core-harmonized-frozen.yml`) *declares* the guarantee; this
*enforces* it.

**Run from:** a session/operator with `nccsdata` bucket-policy rights (`--profile
thiya`). Belongs with the producer (nccs-data-core) or the maintainer — NOT the
nccs-contracts session (governance layer, no infra ownership).

---

## ⚠️ The one way this causes an outage

`nccsdata` is a **shared** bucket (BMF, CORE, efile, lookups, sector-in-brief). The
bucket policy is a **single document**. You MUST read the current policy and **merge**
the new statement — never `put-bucket-policy` a fresh doc, which would drop every other
producer's statements. The procedure below merges idempotently.

---

## Statement to add

**Apply now — delete-protection (recommended first step):**

```json
{
  "Sid": "ProtectFrozenHarmonizedCore-ADR0035",
  "Effect": "Deny",
  "Principal": "*",
  "Action": ["s3:DeleteObject", "s3:DeleteObjectVersion"],
  "Resource": "arn:aws:s3:::nccsdata/harmonized/core/*"
}
```

This denies removal (incl. versioned deletes) for **all** principals — intended; it
stops accidental/programmatic loss. It does **not** block `PutObject`, so ADR 0035
Follow-up 2 (write a one-time `_manifest.json` to the surface) can still proceed.

**Upgrade later — full immutability (AFTER the manifest is written):** add
`"s3:PutObject"` to the `Action` array. That makes the surface truly frozen
(no overwrite), but until you lift it you also can't add files — so do it *after*
Follow-up 2, not before.

Safety check before applying: confirm nothing still writes to `harmonized/core/`. The
current pipeline writes to `intermediate/core/harmonized/` and `processed*/core/`, NOT
`harmonized/core/` (verified 2026-06-26), so this prefix has no live writer — the Deny
is safe.

---

## Procedure (idempotent; safe to re-run)

```bash
PROFILE=thiya
BUCKET=nccsdata

# 1. Pull the CURRENT policy (fall back to an empty policy if none exists yet)
aws s3api get-bucket-policy --bucket "$BUCKET" --profile "$PROFILE" \
  --query Policy --output text > /tmp/nccsdata-policy.json 2>/dev/null \
  || echo '{"Version":"2012-10-17","Statement":[]}' > /tmp/nccsdata-policy.json

# 2. Define the new statement (delete-protection variant)
cat > /tmp/adr0035-stmt.json <<'JSON'
{
  "Sid": "ProtectFrozenHarmonizedCore-ADR0035",
  "Effect": "Deny",
  "Principal": "*",
  "Action": ["s3:DeleteObject", "s3:DeleteObjectVersion"],
  "Resource": "arn:aws:s3:::nccsdata/harmonized/core/*"
}
JSON

# 3. Merge — drop any prior copy of this Sid, then append (idempotent)
jq --slurpfile s /tmp/adr0035-stmt.json '
  .Statement = ([.Statement[] | select(.Sid != "ProtectFrozenHarmonizedCore-ADR0035")] + $s)
' /tmp/nccsdata-policy.json > /tmp/nccsdata-policy-merged.json

# 4. REVIEW the merged document before applying — confirm every pre-existing
#    statement is still present and only this Sid was added.
jq . /tmp/nccsdata-policy-merged.json

# 5. Apply (only after human review of step 4)
aws s3api put-bucket-policy --bucket "$BUCKET" \
  --policy file:///tmp/nccsdata-policy-merged.json --profile "$PROFILE"

# 6. Verify the statement is live
aws s3api get-bucket-policy --bucket "$BUCKET" --profile "$PROFILE" \
  --query Policy --output text | jq '.Statement[] | select(.Sid=="ProtectFrozenHarmonizedCore-ADR0035")'
```

**Optional positive test (safe — uses a nonexistent key):** a delete under the
protected prefix should now return `AccessDenied` rather than succeeding:

```bash
aws s3api delete-object --bucket nccsdata \
  --key 'harmonized/core/__adr0035_denytest__' --profile thiya
# expected: An error occurred (AccessDenied) ...  (proves the Deny is active; no real object touched)
```

---

## Lifting it for a governed change (the ADR's notice + window)

A real future move/retire (after the 90-day notice + deprecation window per ADR 0033)
= temporarily remove the Sid, perform the change, re-apply (or leave removed if the
surface is genuinely retired via the ADR 0005 archive-with-notice path):

```bash
aws s3api get-bucket-policy --bucket nccsdata --profile thiya --query Policy --output text \
  | jq '.Statement = [.Statement[] | select(.Sid != "ProtectFrozenHarmonizedCore-ADR0035")]' \
  > /tmp/nccsdata-policy-lifted.json
aws s3api put-bucket-policy --bucket nccsdata --policy file:///tmp/nccsdata-policy-lifted.json --profile thiya
```

The Deny prevents accidental/programmatic loss; the policy editor (maintainer) can
always lift it deliberately. That recoverability is intended.

---

## Alternative: S3 Object Lock (stronger, heavier)

A bucket policy is liftable by whoever can edit it. For tamper-proof immutability,
S3 **Object Lock** (governance/compliance mode) is stronger — but it requires bucket
**versioning** enabled and cannot be cleanly retrofitted onto existing objects without
care, so the scoped Deny is the pragmatic enforcement here. Revisit Object Lock only if
the governance-only protection proves insufficient.

---

*Spec: ADR `decisions/0035-retain-harmonized-core-frozen-surface.md`; contract
`contracts/core-harmonized-frozen.yml` (`retention:` block). Prefix verified frozen
(2023-12-05 .. 2025-04-21) with no live writer, 2026-06-26.*
