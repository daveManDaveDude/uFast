#!/usr/bin/env python3
"""Validate the frozen WidgetKit and ActivityKit system-surface inventory."""

from __future__ import annotations

import argparse
import importlib.util
import pathlib
import re
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCALIZATION_CHECKER_PATH = ROOT / "scripts/check_localized_literals.py"
SPEC = importlib.util.spec_from_file_location(
    "check_localized_literals",
    LOCALIZATION_CHECKER_PATH,
)
assert SPEC.loader is not None
LOCALIZATION_CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LOCALIZATION_CHECKER)


class SystemSurfaceInventoryError(RuntimeError):
    """A frozen system-surface source or layout contract violation."""


SYSTEM_SURFACE_LAYOUT_INVENTORY = {
    "widgetFamilies": (
        "accessoryRectangular",
        "systemSmall",
        "systemMedium",
        "systemLarge",
    ),
    "activityRegions": (
        "compactLeading",
        "compactTrailing",
        "minimal",
        "expanded",
    ),
    "largeTextConfiguration": "accessibility3",
}

REQUIRED_LAYOUT_ENTRY_POINTS = {
    "accessoryRectangular": (
        pathlib.Path("LockScreenWidget/Widget/UFastLockScreenWidget.swift"),
        (r"\.supportedFamilies\s*\(\s*\[\s*\.accessoryRectangular\b",),
    ),
    "systemSmall": (
        pathlib.Path("LockScreenWidget/Widget/HomeScreenWidget.swift"),
        (r"\.supportedFamilies\s*\([^)]*\.systemSmall\b",),
    ),
    "systemMedium": (
        pathlib.Path("LockScreenWidget/Widget/HomeScreenWidget.swift"),
        (r"\.supportedFamilies\s*\([^)]*\.systemMedium\b",),
    ),
    "systemLarge": (
        pathlib.Path("LockScreenWidget/Widget/HomeScreenWidget.swift"),
        (r"\.supportedFamilies\s*\([^)]*\.systemLarge\b",),
    ),
    "compactLeading": (
        pathlib.Path("LockScreenWidget/Widget/ActiveFastActivityWidget.swift"),
        (r"\bcompactLeadingContent\b", r"\bcompactLeading\s*:"),
    ),
    "compactTrailing": (
        pathlib.Path("LockScreenWidget/Widget/ActiveFastActivityWidget.swift"),
        (r"\bcompactTrailingContent\b", r"\bcompactTrailing\s*:"),
    ),
    "minimal": (
        pathlib.Path("LockScreenWidget/Widget/ActiveFastActivityWidget.swift"),
        (r"\bminimalContent\b", r"\bminimal\s*:"),
    ),
    "expanded": (
        pathlib.Path("LockScreenWidget/Widget/ActiveFastActivityWidget.swift"),
        (r"\bexpandedContent\b", r"\bexpanded\s*:"),
    ),
}

REQUIRED_LAYOUT_SOURCES = tuple(
    dict.fromkeys(
        relative_path
        for relative_path, _ in REQUIRED_LAYOUT_ENTRY_POINTS.values()
    )
)


def check_layout_inventory(root: pathlib.Path = ROOT) -> None:
    missing = []
    source_text: dict[pathlib.Path, str] = {}
    for relative_path in REQUIRED_LAYOUT_SOURCES:
        source_path = root / relative_path
        if not source_path.is_file():
            missing.append(f"missing source: {relative_path}")
            continue
        source_text[relative_path] = source_path.read_text(encoding="utf-8")
    if missing:
        raise SystemSurfaceInventoryError("; ".join(missing))

    missing_entry_points = []
    for identifier, (relative_path, markers) in REQUIRED_LAYOUT_ENTRY_POINTS.items():
        text = source_text[relative_path]
        if not all(re.search(marker, text) for marker in markers):
            missing_entry_points.append(
                f"missing production layout entry point: {identifier} in {relative_path}"
            )
    if missing_entry_points:
        raise SystemSurfaceInventoryError("; ".join(missing_entry_points))


def check(root: pathlib.Path = ROOT) -> None:
    LOCALIZATION_CHECKER.check(root)
    check_layout_inventory(root)


def self_test(root: pathlib.Path = ROOT) -> None:
    check(root)
    with tempfile.TemporaryDirectory(prefix="ufast-system-surface-") as temporary:
        fixture = pathlib.Path(temporary)
        try:
            check_layout_inventory(fixture)
        except SystemSurfaceInventoryError:
            pass
        else:
            raise SystemSurfaceInventoryError("missing layout source negative control passed")

        fixture_sources = {
            relative_path: (root / relative_path).read_text(encoding="utf-8")
            for relative_path in REQUIRED_LAYOUT_SOURCES
        }
        family_source = pathlib.Path("LockScreenWidget/Widget/HomeScreenWidget.swift")
        (fixture / family_source).parent.mkdir(parents=True, exist_ok=True)
        for relative_path, text in fixture_sources.items():
            destination = fixture / relative_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(text, encoding="utf-8")
        (fixture / family_source).write_text(
            fixture_sources[family_source].replace(".systemMedium", ".removedSystemMedium"),
            encoding="utf-8",
        )
        try:
            check_layout_inventory(fixture)
        except SystemSurfaceInventoryError as error:
            if "systemMedium" not in str(error):
                raise SystemSurfaceInventoryError(
                    f"widget-family negative control reported the wrong failure: {error}"
                ) from error
        else:
            raise SystemSurfaceInventoryError("missing widget family negative control passed")
    print("system-surface inventory checker self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.self_test:
            self_test()
        else:
            check()
            print("system-surface inventory check passed")
    except (SystemSurfaceInventoryError, OSError) as error:
        print(f"system-surface inventory check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
