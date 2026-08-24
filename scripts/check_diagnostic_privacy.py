#!/usr/bin/env python3
"""Check the D-037 diagnostic boundary and widget log inventory."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
EVENT_PATH = pathlib.Path("LockScreenShared/DiagnosticEvent.swift")
WIDGET_BOUNDARY_PATHS = (
    pathlib.Path("uFast/App/WidgetProjectionSupport.swift"),
    pathlib.Path("LockScreenShared/ActiveFastProjectionFileStore.swift"),
    pathlib.Path("LockScreenWidget/Widget/UFastLockScreenWidget.swift"),
)
ADAPTER_PATHS = (
    pathlib.Path("uFast/App/AppDiagnosticEventLogSink.swift"),
    pathlib.Path("LockScreenWidget/Widget/WidgetDiagnosticEventLogSink.swift"),
)
EXPECTED_SUBSYSTEMS = (
    "persistence",
    "command",
    "history",
    "widgetProjection",
    "liveActivity",
)
EXPECTED_OUTCOMES = (
    "storeOpenFailed",
    "migrationFailed",
    "authorityConflict",
    "commitFailed",
    "rollbackApplied",
    "postCommitProjectionFailed",
    "initialLoadFailed",
    "extensionLoadFailed",
    "containerUnavailable",
    "publishFailed",
    "clearFailed",
    "unavailable",
    "requestFailed",
    "updateFailed",
    "endFailed",
)


class DiagnosticPrivacyError(RuntimeError):
    pass


def read(root: pathlib.Path, relative: pathlib.Path) -> str:
    path = root / relative
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        raise DiagnosticPrivacyError(f"could not read {relative}: {error}") from error


def check(root: pathlib.Path = ROOT) -> None:
    event_source = read(root, EVENT_PATH)
    for value in EXPECTED_SUBSYSTEMS + EXPECTED_OUTCOMES:
        if f"case {value}" not in event_source:
            raise DiagnosticPrivacyError(f"closed vocabulary value is missing: {value}")
    if re.search(r"\bDictionary\b|\[String:\s*Any\]|\bAny\b", event_source):
        raise DiagnosticPrivacyError("diagnostic event source contains a generic metadata container")
    if "String(describing:" in event_source or "uuidString" in event_source:
        raise DiagnosticPrivacyError("diagnostic event source contains a raw error or full identifier")

    for relative in WIDGET_BOUNDARY_PATHS:
        source = read(root, relative)
        forbidden = (
            "import OSLog",
            "Logger(",
            "logger.",
            "String(describing: error)",
            "privacy: .public)",
            "uuidString",
        )
        found = [token for token in forbidden if token in source]
        if found:
            raise DiagnosticPrivacyError(
                f"free-form widget logging remains in {relative}: {', '.join(found)}"
            )

    for relative in ADAPTER_PATHS:
        source = read(root, relative)
        if "Logger(" not in source or "import OSLog" not in source:
            raise DiagnosticPrivacyError(f"separate OSLog adapter is incomplete: {relative}")
        if "String(describing:" in source or "uuidString" in source:
            raise DiagnosticPrivacyError(f"raw diagnostic payload remains in {relative}")


def self_test(root: pathlib.Path = ROOT) -> None:
    check(root)
    with tempfile.TemporaryDirectory(prefix="ufast-diagnostic-privacy-") as temporary:
        fixture_root = pathlib.Path(temporary)
        for relative in (EVENT_PATH, *WIDGET_BOUNDARY_PATHS, *ADAPTER_PATHS):
            path = fixture_root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("struct Fixture {}\n", encoding="utf-8")
        (fixture_root / EVENT_PATH).write_text(
            "enum DiagnosticSubsystem { case persistence }\n"
            "enum DiagnosticOutcome { case storeOpenFailed }\n",
            encoding="utf-8",
        )
        for value in EXPECTED_SUBSYSTEMS[1:] + EXPECTED_OUTCOMES[1:]:
            with (fixture_root / EVENT_PATH).open("a", encoding="utf-8") as handle:
                handle.write(f"case {value}\n")
        for relative in ADAPTER_PATHS:
            (fixture_root / relative).write_text(
                "import OSLog\nstruct Adapter { let logger = Logger() }\n",
                encoding="utf-8",
            )
        (fixture_root / WIDGET_BOUNDARY_PATHS[0]).write_text(
            "import OSLog\nlet logger = Logger()\nlogger.error(\"food \(name)\")\n",
            encoding="utf-8",
        )
        try:
            check(fixture_root)
        except DiagnosticPrivacyError:
            print("negative control passed: free-form user-content widget log")
        else:
            raise DiagnosticPrivacyError("negative control unexpectedly passed")

        (fixture_root / WIDGET_BOUNDARY_PATHS[0]).write_text(
            "struct Fixture {}\n",
            encoding="utf-8",
        )
        (fixture_root / WIDGET_BOUNDARY_PATHS[2]).write_text(
            "import OSLog\n"
            "let logger = Logger()\n"
            "logger.error(\"id=\\(uuidString) error=\\(String(describing: error))\")\n",
            encoding="utf-8",
        )
        try:
            check(fixture_root)
        except DiagnosticPrivacyError:
            print("negative control passed: provider identifier/raw-error log")
        else:
            raise DiagnosticPrivacyError("provider negative control unexpectedly passed")
    print("diagnostic privacy self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        self_test() if args.self_test else check()
    except DiagnosticPrivacyError as error:
        print(f"diagnostic privacy check failed: {error}", file=sys.stderr)
        return 1
    if not args.self_test:
        print("diagnostic privacy check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
