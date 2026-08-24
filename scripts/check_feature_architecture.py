#!/usr/bin/env python3
"""Enforce the feature-to-persistence dependency seam.

The allowlist is deliberately exact and is checked against a matching baseline
in this script so a new exception requires a reviewed source change as well as
a policy edit. The History exceptions are now retired; the self-test exercises
the empty policy and forbidden-source controls.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import sys
import tempfile
from collections.abc import Iterable
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[1]
POLICY_RELATIVE_PATH = pathlib.Path("docs/FEATURE_ARCHITECTURE_ALLOWLIST.json")
EXPECTED_ALLOWLIST: dict[str, tuple[str, ...]] = {}
EXPECTED_FORBIDDEN_CATEGORIES = {
    "swiftdata_import": "import SwiftData",
    "query": "@Query",
    "model_context_environment": "@Environment(\\.modelContext)",
    "model_context": "ModelContext",
    "fetch_descriptor": "FetchDescriptor",
    "persistent_record_type": (
        "current SwiftData record type reference (AppSettingsRecord, FastRecord, "
        "FoodEntryRecord, HydrationEntryRecord, HydrationFavouriteRecord, or UnknownPeriodRecord)"
    ),
}

PATTERNS: dict[str, re.Pattern[str]] = {
    "swiftdata_import": re.compile(r"(?m)^\s*import\s+SwiftData\b"),
    "query": re.compile(r"(?m)^\s*@Query\b"),
    "model_context_environment": re.compile(r"@Environment\(\s*\\\.modelContext\s*\)"),
    "model_context": re.compile(r"\bModelContext\b"),
    "fetch_descriptor": re.compile(r"\bFetchDescriptor\b"),
    "persistent_record_type": re.compile(
        r"\b(?:AppSettingsRecord|FastRecord|FoodEntryRecord|HydrationEntryRecord|"
        r"HydrationFavouriteRecord|UnknownPeriodRecord)\b"
    ),
}


class ArchitectureCheckError(RuntimeError):
    """A feature dependency policy or source violation."""


def load_policy(path: pathlib.Path) -> dict[str, Any]:
    try:
        policy = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ArchitectureCheckError(f"could not read architecture policy {path}: {error}") from error
    if not isinstance(policy, dict):
        raise ArchitectureCheckError("architecture policy must be a JSON object")
    return policy


def policy_allowlist(policy: dict[str, Any]) -> dict[str, tuple[str, ...]]:
    if policy.get("protected_root") != "uFast/Features":
        raise ArchitectureCheckError("architecture policy protected_root must be exactly uFast/Features")
    categories = policy.get("forbidden_categories")
    if categories != EXPECTED_FORBIDDEN_CATEGORIES:
        raise ArchitectureCheckError(
            "architecture policy forbidden_categories changed without a reviewed baseline update"
        )

    raw_allowlist = policy.get("allowlist")
    if not isinstance(raw_allowlist, list):
        raise ArchitectureCheckError("architecture policy allowlist must be a list")

    parsed: dict[str, tuple[str, ...]] = {}
    for entry in raw_allowlist:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            raise ArchitectureCheckError("every architecture allowlist entry needs an exact path")
        path = entry["path"]
        reasons = entry.get("reasons")
        if not isinstance(reasons, list) or not all(isinstance(reason, str) for reason in reasons):
            raise ArchitectureCheckError(f"allowlist reasons are invalid for {path}")
        if path in parsed:
            raise ArchitectureCheckError(f"duplicate architecture allowlist path: {path}")
        if not set(reasons).issubset(PATTERNS):
            raise ArchitectureCheckError(f"unknown forbidden category in allowlist entry: {path}")
        parsed[path] = tuple(reasons)

    if parsed != EXPECTED_ALLOWLIST:
        raise ArchitectureCheckError(
            "architecture allowlist changed without a reviewed baseline update: "
            f"expected {sorted(EXPECTED_ALLOWLIST)}, got {sorted(parsed)}"
        )
    return parsed


def feature_paths(root: pathlib.Path) -> Iterable[pathlib.Path]:
    protected_root = root / "uFast/Features"
    if not protected_root.is_dir():
        raise ArchitectureCheckError(f"protected feature root is missing: {protected_root}")
    return sorted(protected_root.rglob("*.swift"))


def categories_in(text: str) -> tuple[str, ...]:
    return tuple(category for category, pattern in PATTERNS.items() if pattern.search(text))


def check(root: pathlib.Path = ROOT, policy_path: pathlib.Path | None = None) -> None:
    policy = load_policy(policy_path or root / POLICY_RELATIVE_PATH)
    allowlist = policy_allowlist(policy)
    violations: list[str] = []
    for path in feature_paths(root):
        relative_path = path.relative_to(root).as_posix()
        observed = categories_in(path.read_text(encoding="utf-8"))
        if not observed:
            continue
        expected = allowlist.get(relative_path)
        if expected is None:
            violations.append(f"{relative_path}: forbidden categories {', '.join(observed)}")
        elif observed != expected:
            violations.append(
                f"{relative_path}: observed categories {', '.join(observed)} do not match "
                f"reviewed reasons {', '.join(expected)}"
            )
    if violations:
        raise ArchitectureCheckError("feature dependency check failed:\n- " + "\n- ".join(violations))


def expect_failure(label: str, action: Any) -> None:
    try:
        action()
    except ArchitectureCheckError:
        print(f"negative control passed: {label}")
    else:
        raise ArchitectureCheckError(f"negative control unexpectedly passed: {label}")


def self_test(root: pathlib.Path = ROOT) -> None:
    check(root)
    with tempfile.TemporaryDirectory(prefix="ufast-architecture-") as temporary:
        fixture_root = pathlib.Path(temporary)
        (fixture_root / "uFast/Features/Fasting").mkdir(parents=True)
        (fixture_root / "docs").mkdir()
        shutil.copy2(root / POLICY_RELATIVE_PATH, fixture_root / POLICY_RELATIVE_PATH)
        clean = fixture_root / "uFast/Features/Temporary.swift"
        clean.write_text("import SwiftUI\nstruct TemporaryView {}\n", encoding="utf-8")

        clean.write_text("import SwiftData\nstruct TemporaryView {}\n", encoding="utf-8")
        expect_failure("unapproved feature import SwiftData", lambda: check(fixture_root))
        clean.write_text("import SwiftUI\nstruct TemporaryView {}\n", encoding="utf-8")

        policy_path = fixture_root / POLICY_RELATIVE_PATH
        policy = load_policy(policy_path)
        policy["allowlist"].append({"path": "uFast/Features/Temporary.swift", "reasons": []})
        policy_path.write_text(json.dumps(policy), encoding="utf-8")
        expect_failure("fourth allowlisted feature path", lambda: check(fixture_root))

    print("architecture dependency self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run positive and negative policy controls")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
        else:
            check()
            print("feature dependency check passed")
    except ArchitectureCheckError as error:
        print(f"feature dependency check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
