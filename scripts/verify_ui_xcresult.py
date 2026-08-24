#!/usr/bin/env python3

"""Verify the completeness and four-worker shape of a uFast UI test result."""

from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import subprocess
import sys
import tempfile
from typing import Any, Iterable


class VerificationError(RuntimeError):
    pass


def walk_json(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk_json(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_json(child)


def expected_tests(source_directory: pathlib.Path) -> set[str]:
    declaration_pattern = re.compile(
        r"^\s*(?:(?:final\s+)?class\s+(?P<class_name>\w+)\s*:\s*(?P<parent>\w+)|"
        r"extension\s+(?P<extension_name>\w+))",
        re.MULTILINE,
    )
    test_pattern = re.compile(r"^\s*func\s+(test[A-Za-z0-9_]+)\s*\(", re.MULTILINE)
    expected: set[str] = set()
    sources: list[tuple[str, str, list[re.Match[str]]]] = []
    inheritance: dict[str, str] = {}

    for source_path in sorted(source_directory.rglob("*.swift")):
        source = source_path.read_text(encoding="utf-8")
        declarations = list(declaration_pattern.finditer(source))
        if not declarations:
            continue
        sources.append((source_path.name, source, declarations))
        inheritance.update(
            {
                declaration.group("class_name"): declaration.group("parent")
                for declaration in declarations
                if declaration.group("class_name") is not None
            }
        )

        def derives_from_xctest(class_name: str) -> bool:
            visited: set[str] = set()
            current = class_name
            while current != "XCTestCase":
                if current in visited:
                    return False
                visited.add(current)
                current = inheritance.get(current, "")
                if not current:
                    return False
            return True

    for _, source, declarations in sources:
        for index, declaration in enumerate(declarations):
            class_name = declaration.group("class_name") or declaration.group("extension_name")
            if class_name is None:
                continue
            if not derives_from_xctest(class_name):
                continue
            next_start = declarations[index + 1].start() if index + 1 < len(declarations) else len(source)
            class_body = source[declaration.end() : next_start]
            expected.update(
                f"{class_name}/{method}()" for method in test_pattern.findall(class_body)
            )

    if not expected:
        raise VerificationError(f"No UI tests discovered in {source_directory}")
    return expected


def actual_tests(test_results: dict[str, Any]) -> list[tuple[str, str]]:
    actual: list[tuple[str, str]] = []
    for node in walk_json(test_results):
        if node.get("nodeType") != "Test Case":
            continue
        url = str(node.get("nodeIdentifierURL", ""))
        if "/uFastUITests/" not in url:
            continue
        identifier = node.get("nodeIdentifier")
        result = node.get("result")
        if not isinstance(identifier, str) or not isinstance(result, str):
            raise VerificationError("A UI test result is missing its identifier or result")
        actual.append((identifier, result))
    return actual


def verify_payloads(
    expected: set[str],
    test_results: dict[str, Any],
    action_log: dict[str, Any],
    worker_count: int,
) -> tuple[int, int]:
    actual = actual_tests(test_results)
    counts = collections.Counter(identifier for identifier, _ in actual)
    missing = sorted(expected - counts.keys())
    unexpected = sorted(counts.keys() - expected)
    duplicated = sorted(identifier for identifier, count in counts.items() if count != 1)
    skipped = sorted(identifier for identifier, result in actual if result == "Skipped")
    failed = sorted(identifier for identifier, result in actual if result not in {"Passed", "Skipped"})

    problems: list[str] = []
    if missing:
        problems.append("missing: " + ", ".join(missing))
    if unexpected:
        problems.append("unexpected: " + ", ".join(unexpected))
    if duplicated:
        problems.append("not exactly once: " + ", ".join(duplicated))
    if skipped:
        problems.append("skipped: " + ", ".join(skipped))
    if failed:
        problems.append("not passed: " + ", ".join(failed))

    workers = [
        node
        for node in walk_json(action_log)
        if node.get("domainType") == "com.apple.dt.IDE.UnitTestLogSection.Worker"
    ]
    if len(workers) != worker_count:
        problems.append(f"started test-worker clones: {len(workers)} (expected {worker_count})")
    unsuccessful_workers = [worker for worker in workers if worker.get("result") != "succeeded"]
    if unsuccessful_workers:
        problems.append(f"unsuccessful test-worker clones: {len(unsuccessful_workers)}")

    if problems:
        raise VerificationError("UI result verification failed:\n- " + "\n- ".join(problems))
    return len(actual), len(workers)


def xcresult_json(result_path: pathlib.Path, arguments: list[str]) -> dict[str, Any]:
    command = ["xcrun", "xcresulttool", *arguments, "--path", str(result_path), "--compact"]
    completed = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(completed.stdout)


def self_test() -> None:
    with tempfile.TemporaryDirectory() as directory:
        source_directory = pathlib.Path(directory)
        (source_directory / "ExampleUITests.swift").write_text(
            "final class ExampleUITests: XCTestCase {\n"
            "    func testOne() {}\n"
            "}\n"
            "extension ExampleUITests {\n"
            "    func testTwo() throws {}\n"
            "}\n",
            encoding="utf-8",
        )
        support_directory = source_directory / "Support"
        support_directory.mkdir()
        (support_directory / "UITestLaunchConfigurationTests.swift").write_text(
            "final class UITestLaunchConfigurationTests: XCTestCase {\n"
            "    func testConfiguration() {}\n"
            "}\n",
            encoding="utf-8",
        )
        discovered = expected_tests(source_directory)

    expected = {
        "ExampleUITests/testOne()",
        "ExampleUITests/testTwo()",
        "UITestLaunchConfigurationTests/testConfiguration()",
    }
    if discovered != expected:
        raise VerificationError(f"Unexpected source inventory: {sorted(discovered)}")
    cases = [
        {
            "nodeType": "Test Case",
            "nodeIdentifier": identifier,
            "nodeIdentifierURL": f"test://uFast/uFastUITests/{identifier.removesuffix('()')}",
            "result": "Passed",
        }
        for identifier in sorted(expected)
    ]
    tests = {"testNodes": cases}
    action = {
        "subsections": [
            {"domainType": "com.apple.dt.IDE.UnitTestLogSection.Worker", "result": "succeeded"}
            for _ in range(4)
        ]
    }
    verify_payloads(expected, tests, action, 4)

    invalid_payloads = [
        ({"testNodes": cases[:-1]}, action),
        ({"testNodes": cases + [cases[0]]}, action),
        ({"testNodes": [{**cases[0], "result": "Skipped"}, cases[1]]}, action),
        (tests, {"subsections": action["subsections"][:-1]}),
        (
            tests,
            {
                "subsections": [
                    *action["subsections"][:-1],
                    {
                        "domainType": "com.apple.dt.IDE.UnitTestLogSection.Worker",
                        "result": "failed",
                    },
                ]
            },
        ),
    ]
    for invalid_tests, invalid_action in invalid_payloads:
        try:
            verify_payloads(expected, invalid_tests, invalid_action, 4)
        except VerificationError:
            continue
        raise VerificationError("Verifier self-test accepted an invalid result")
    print("UI xcresult verifier self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("xcresult", nargs="?", type=pathlib.Path)
    parser.add_argument("--ui-tests", type=pathlib.Path)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()

    try:
        if arguments.self_test:
            self_test()
            return 0
        if arguments.xcresult is None:
            parser.error("xcresult is required unless --self-test is used")

        repository_root = pathlib.Path(__file__).resolve().parent.parent
        source_directory = arguments.ui_tests or repository_root / "uFastUITests"
        tests = xcresult_json(
            arguments.xcresult,
            ["get", "test-results", "tests"],
        )
        action = xcresult_json(arguments.xcresult, ["get", "log", "--type", "action"])
        count, workers = verify_payloads(
            expected_tests(source_directory),
            tests,
            action,
            arguments.workers,
        )
        print(f"UI xcresult verified: {count} tests exactly once, 0 skipped, {workers} worker clones")
        print(arguments.xcresult.resolve())
        return 0
    except (VerificationError, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
