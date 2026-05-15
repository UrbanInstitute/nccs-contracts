#!/usr/bin/env python3
"""Validate every contracts/*.yml against the contract template structure.

Run locally:
    python3 scripts/validate_contracts.py

Run in CI via .github/workflows/contracts-validate.yml.

Exits 0 if all contracts pass; 1 if any fail. Reports all failures
before exiting (does not stop at first failure).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("error: PyYAML is required. Install with `pip install pyyaml`.")


REPO_ROOT = Path(__file__).resolve().parent.parent
CONTRACTS_DIR = REPO_ROOT / "contracts"
TEMPLATE_FILENAME = "_template.yml"

REQUIRED_TOP_LEVEL = [
    "name",
    "description",
    "producer",
    "format",
    "s3",
    "cadence",
    "manifest",
    "schema",
    "consumers",
    "drift_detection",
    "deprecation_window_days",
]

REQUIRED_NESTED = {
    "producer": ["repo"],
    "s3": ["bucket", "key_prefix"],
    "cadence": ["type"],
    "drift_detection": ["trigger"],
}

KEBAB_NAME = re.compile(r"^[a-z][a-z0-9-]*$")


def validate_contract(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        doc = yaml.safe_load(path.read_text())
    except yaml.YAMLError as e:
        return [f"{path.name}: YAML parse error: {e}"]

    if not isinstance(doc, dict):
        return [f"{path.name}: top-level must be a mapping, got {type(doc).__name__}"]

    for field in REQUIRED_TOP_LEVEL:
        if field not in doc:
            errors.append(f"{path.name}: missing required field `{field}`")

    name = doc.get("name")
    if isinstance(name, str) and not KEBAB_NAME.match(name):
        errors.append(
            f"{path.name}: name `{name}` must be kebab-case "
            f"(lowercase, digits, hyphens; must start with a letter)"
        )

    for parent, children in REQUIRED_NESTED.items():
        section = doc.get(parent)
        if not isinstance(section, dict):
            continue  # already reported as missing above, or wrong type
        for child in children:
            if child not in section:
                errors.append(f"{path.name}: missing required field `{parent}.{child}`")

    return errors


def main() -> int:
    if not CONTRACTS_DIR.is_dir():
        print(f"error: contracts/ not found at {CONTRACTS_DIR}", file=sys.stderr)
        return 1

    files = sorted(p for p in CONTRACTS_DIR.glob("*.yml") if p.name != TEMPLATE_FILENAME)
    if not files:
        print(f"error: no contracts found in {CONTRACTS_DIR}", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    names: dict[str, str] = {}  # name -> filename

    for path in files:
        errs = validate_contract(path)
        all_errors.extend(errs)
        try:
            doc = yaml.safe_load(path.read_text())
            if isinstance(doc, dict):
                n = doc.get("name")
                if isinstance(n, str):
                    if n in names:
                        all_errors.append(
                            f"{path.name}: name `{n}` is also used by {names[n]}"
                        )
                    else:
                        names[n] = path.name
        except yaml.YAMLError:
            pass  # already reported

    if all_errors:
        print("Contract validation FAILED:\n", file=sys.stderr)
        for e in all_errors:
            print(f"  - {e}", file=sys.stderr)
        print(f"\n{len(all_errors)} error(s) across {len(files)} contract(s).", file=sys.stderr)
        return 1

    print(f"OK: {len(files)} contract(s) validated, {len(names)} unique name(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
