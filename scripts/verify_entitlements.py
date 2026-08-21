#!/usr/bin/env python3
"""Verify the local-only entitlement contract for source or built products.

Source entitlement files are intentionally strict: the only entitlement is the
shared widget App Group. Built products may contain the signing metadata that
Xcode adds, but no capability entitlement outside the explicit allowlist is
accepted.
"""

from __future__ import annotations

import argparse
import pathlib
import plistlib
import subprocess
import sys
import tempfile
from typing import Any


APP_GROUP = "group.com.davidmcgrath.uFast.widgets"
APP_BUNDLE_ID = "com.davidmcgrath.uFast"
WIDGET_BUNDLE_ID = "com.davidmcgrath.uFast.Widget"
SOURCE_KEYS = {"com.apple.security.application-groups"}
BUILT_KEYS = {
    "application-identifier",
    "com.apple.developer.team-identifier",
    "com.apple.security.application-groups",
    "get-task-allow",
}


class EntitlementError(RuntimeError):
    pass


def load_plist(path: pathlib.Path) -> dict[str, Any]:
    if not path.is_file():
        raise EntitlementError(f"missing entitlement file: {path}")
    try:
        with path.open("rb") as handle:
            value = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        raise EntitlementError(f"invalid entitlement plist: {path}: {error}") from error
    if not isinstance(value, dict):
        raise EntitlementError(f"entitlement plist is not a dictionary: {path}")
    return value


def load_built(path: pathlib.Path) -> dict[str, Any]:
    """Read an xcent plist or the signed entitlements from a product."""

    if path.is_file():
        return load_plist(path)
    if not path.exists():
        raise EntitlementError(f"missing built product or entitlement file: {path}")
    try:
        completed = subprocess.run(
            ["codesign", "-d", "--entitlements", "-", str(path)],
            check=True,
            capture_output=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise EntitlementError(f"could not extract built entitlements: {path}: {error}") from error
    try:
        value = plistlib.loads(completed.stdout)
    except (plistlib.InvalidFileException, ValueError) as error:
        raise EntitlementError(f"invalid extracted entitlements: {path}: {error}") from error
    if not isinstance(value, dict):
        raise EntitlementError(f"extracted entitlements are not a dictionary: {path}")
    return value


def verify(path: pathlib.Path, *, kind: str, expected_bundle_id: str) -> None:
    values = load_plist(path) if kind == "source" else load_built(path)
    allowed = SOURCE_KEYS if kind == "source" else BUILT_KEYS
    unexpected = sorted(set(values) - allowed)
    if unexpected:
        raise EntitlementError(
            f"{kind} entitlement allowlist rejected {path}: unexpected keys: {', '.join(unexpected)}"
        )

    groups = values.get("com.apple.security.application-groups")
    if groups != [APP_GROUP]:
        raise EntitlementError(
            f"{kind} entitlement App Group mismatch for {path}: expected [{APP_GROUP!r}], got {groups!r}"
        )

    if kind == "built":
        identifier = values.get("application-identifier")
        if not isinstance(identifier, str) or not identifier.endswith(expected_bundle_id):
            raise EntitlementError(
                f"built entitlement bundle identifier mismatch for {path}: {identifier!r}"
            )


def verify_pair(
    app: pathlib.Path,
    widget: pathlib.Path,
    *,
    kind: str,
) -> None:
    verify(app, kind=kind, expected_bundle_id=APP_BUNDLE_ID)
    verify(widget, kind=kind, expected_bundle_id=WIDGET_BUNDLE_ID)
    print(f"{kind} entitlement verification passed: app={app} widget={widget}")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="uFast-entitlements-") as directory:
        root = pathlib.Path(directory)
        app = root / "UFast.entitlements"
        widget = root / "UFastLockScreenWidget.entitlements"
        good = {
            "com.apple.security.application-groups": [APP_GROUP],
        }
        for path in (app, widget):
            with path.open("wb") as handle:
                plistlib.dump(good, handle)
        verify_pair(app, widget, kind="source")

        built_app = root / "uFast.app-Simulated.xcent"
        built_widget = root / "uFast Widget.appex-Simulated.xcent"
        built_good = {
            **good,
            "application-identifier": "QY9XGBM7T5.com.davidmcgrath.uFast",
            "com.apple.developer.team-identifier": "QY9XGBM7T5",
            "get-task-allow": True,
        }
        built_widget_good = {
            **good,
            "application-identifier": "QY9XGBM7T5.com.davidmcgrath.uFast.Widget",
            "com.apple.developer.team-identifier": "QY9XGBM7T5",
            "get-task-allow": True,
        }
        for path, values in ((built_app, built_good), (built_widget, built_widget_good)):
            with path.open("wb") as handle:
                plistlib.dump(values, handle)
        verify_pair(built_app, built_widget, kind="built")

        cases = {
            "missing": lambda: verify_pair(app.with_name("missing"), widget, kind="source"),
            "forbidden": lambda: write_and_verify(
                app,
                {**good, "com.apple.developer.icloud-container-identifiers": ["iCloud.bad"]},
                kind="source",
                widget=widget,
            ),
            "wrong-app-group": lambda: write_and_verify(
                app,
                {"com.apple.security.application-groups": ["group.bad"]},
                kind="source",
                widget=widget,
            ),
            "built-missing": lambda: verify_pair(
                root / "missing-built.xcent", built_widget, kind="built"
            ),
            "built-forbidden": lambda: write_and_verify(
                built_app,
                {**built_good, "com.apple.developer.icloud-container-identifiers": ["iCloud.bad"]},
                kind="built",
                widget=built_widget,
            ),
            "built-value": lambda: write_and_verify(
                built_app,
                {**built_good, "com.apple.security.application-groups": ["group.bad"]},
                kind="built",
                widget=built_widget,
            ),
            "built-bundle-id": lambda: write_and_verify(
                built_widget,
                {**built_widget_good, "application-identifier": "QY9XGBM7T5.com.bad.Widget"},
                kind="built",
                widget=built_widget,
            ),
        }
        for name, action in cases.items():
            try:
                action()
            except EntitlementError:
                continue
            raise EntitlementError(f"entitlement self-test accepted invalid {name} fixture")
        print("Entitlement verifier self-test passed")


def write_and_verify(
    app: pathlib.Path,
    values: dict[str, Any],
    *,
    kind: str,
    widget: pathlib.Path,
) -> None:
    with app.open("wb") as handle:
        plistlib.dump(values, handle)
    verify_pair(app, widget, kind=kind)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=pathlib.Path)
    parser.add_argument("--widget", type=pathlib.Path)
    parser.add_argument("--built-app", type=pathlib.Path)
    parser.add_argument("--built-widget", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()

    try:
        if arguments.self_test:
            self_test()
            return 0
        root = pathlib.Path(__file__).resolve().parent.parent
        app = arguments.app or root / "uFast/SupportingFiles/UFast.entitlements"
        widget = arguments.widget or root / "LockScreenWidget/Widget/UFastLockScreenWidget.entitlements"
        if (arguments.built_app is None) != (arguments.built_widget is None):
            parser.error("--built-app and --built-widget must be supplied together")
        verify_pair(app, widget, kind="source")
        if arguments.built_app and arguments.built_widget:
            verify_pair(arguments.built_app, arguments.built_widget, kind="built")
        return 0
    except EntitlementError as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
