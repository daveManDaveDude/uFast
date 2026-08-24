#!/usr/bin/env python3
"""Keep UI-test launch flags aligned with AppLaunchConfiguration and its builder."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import tempfile
from collections.abc import Iterable
from typing import Callable


ROOT = pathlib.Path(__file__).resolve().parents[1]
PRODUCTION_PATH = pathlib.Path("uFast/App/AppLaunchConfiguration.swift")
BUILDER_PATH = pathlib.Path("uFastUITests/Support/UITestLaunchConfiguration.swift")
BUILDER_TEST_PATH = pathlib.Path("uFastUITests/Support/UITestLaunchConfigurationTests.swift")
UI_TESTS_PATH = pathlib.Path("uFastUITests")
FLAG_PATTERN = re.compile(r'"(--[A-Za-z0-9-]+)"')
UNSUPPORTED_MARKER = "ui-test-unsupported-launch-argument"


class LaunchArgumentCheckError(RuntimeError):
    """A launch-argument contract or source violation."""


def flags_in(path: pathlib.Path) -> set[str]:
    return set(FLAG_PATTERN.findall(path.read_text(encoding="utf-8")))


def source_flags(path: pathlib.Path) -> Iterable[tuple[str, int, str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    for line_number, line in enumerate(lines, start=1):
        previous_line = lines[line_number - 2] if line_number > 1 else ""
        context = f"{previous_line} {line}"
        for flag in FLAG_PATTERN.findall(line):
            yield flag, line_number, context.strip()


def production_flags(root: pathlib.Path) -> set[str]:
    path = root / PRODUCTION_PATH
    if not path.is_file():
        raise LaunchArgumentCheckError(f"production parser is missing: {path}")
    return flags_in(path)


def builder_flags(root: pathlib.Path) -> set[str]:
    path = root / BUILDER_PATH
    if not path.is_file():
        raise LaunchArgumentCheckError(f"typed UI-test builder is missing: {path}")
    return flags_in(path)


def direct_ui_flags(root: pathlib.Path) -> list[tuple[str, str, int, str]]:
    violations: list[tuple[str, str, int, str]] = []
    ui_root = root / UI_TESTS_PATH
    allowed_builder_sources = {root / BUILDER_PATH, root / BUILDER_TEST_PATH}
    for path in sorted(ui_root.rglob("*.swift")):
        if path in allowed_builder_sources:
            continue
        relative_path = path.relative_to(root).as_posix()
        for flag, line_number, source in source_flags(path):
            violations.append((flag, relative_path, line_number, source))
    return violations


def check(root: pathlib.Path = ROOT) -> None:
    parser = production_flags(root)
    builder = builder_flags(root)
    missing = sorted(parser - builder)
    extra = sorted(builder - parser)
    if missing or extra:
        details = []
        if missing:
            details.append("missing from builder: " + ", ".join(missing))
        if extra:
            details.append("not accepted by production parser: " + ", ".join(extra))
        raise LaunchArgumentCheckError("launch grammar mismatch: " + "; ".join(details))

    direct_violations = direct_ui_flags(root)
    unsupported = [violation for violation in direct_violations if violation[0] not in parser]
    supported = [violation for violation in direct_violations if violation[0] in parser]
    undocumented = [violation for violation in unsupported if UNSUPPORTED_MARKER not in violation[3]]
    if supported or undocumented:
        details = [
            f"{flag} at {path}:{line}"
            for flag, path, line, _ in [*supported, *undocumented]
        ]
        raise LaunchArgumentCheckError(
            "raw UI-test launch arguments are outside the typed builder: " + "; ".join(details)
        )


def expect_failure(label: str, action: Callable[[], None]) -> None:
    try:
        action()
    except LaunchArgumentCheckError:
        print(f"negative control passed: {label}")
    else:
        raise LaunchArgumentCheckError(f"negative control unexpectedly passed: {label}")


def self_test(root: pathlib.Path = ROOT) -> None:
    check(root)
    with tempfile.TemporaryDirectory(prefix="ufast-ui-launch-") as temporary:
        fixture_root = pathlib.Path(temporary)
        (fixture_root / PRODUCTION_PATH).parent.mkdir(parents=True)
        (fixture_root / BUILDER_PATH).parent.mkdir(parents=True)
        (fixture_root / UI_TESTS_PATH).mkdir(parents=True, exist_ok=True)
        (fixture_root / PRODUCTION_PATH).write_text(
            'let gate = arguments.contains("--ui-testing")\n'
            'let reset = arguments.contains("--reset-data")\n',
            encoding="utf-8",
        )
        builder = fixture_root / BUILDER_PATH
        builder.write_text(
            'let flags = ["--ui-testing", "--reset-data"]\n',
            encoding="utf-8",
        )
        (fixture_root / UI_TESTS_PATH / "Clean.swift").write_text(
            "let arguments = UITestLaunchConfiguration().arguments\n",
            encoding="utf-8",
        )
        check(fixture_root)

        support_helper = fixture_root / UI_TESTS_PATH / "Support" / "Helper.swift"
        support_helper.write_text('let arguments = ["--reset-data"]\n', encoding="utf-8")
        expect_failure("supported raw flag in non-builder Support file", lambda: check(fixture_root))
        support_helper.unlink()

        direct = fixture_root / UI_TESTS_PATH / "Direct.swift"
        direct.write_text('let arguments = ["--reset-data"]\n', encoding="utf-8")
        expect_failure("supported raw UI flag", lambda: check(fixture_root))
        direct.write_text('let arguments = ["--diagnostic"]\n', encoding="utf-8")
        expect_failure("undocumented diagnostic flag", lambda: check(fixture_root))
        direct.write_text(
            '// ui-test-unsupported-launch-argument: --diagnostic\n'
            'let arguments = ["--diagnostic"]\n',
            encoding="utf-8",
        )
        check(fixture_root)
        builder.write_text('let flags = ["--ui-testing"]\n', encoding="utf-8")
        expect_failure("builder missing parser flag", lambda: check(fixture_root))

    print("UI-test launch argument checker self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.self_test:
            self_test()
        else:
            check()
            print("UI-test launch argument check passed")
    except (LaunchArgumentCheckError, OSError) as error:
        print(f"UI-test launch argument check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
