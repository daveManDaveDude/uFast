#!/usr/bin/env python3
"""Validate the migrated presentation boundary and its String Catalog."""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
import tempfile
from collections.abc import Iterable
from typing import NamedTuple


ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOG_PATH = pathlib.Path("uFast/Resources/Localizable.xcstrings")
APP_TEXT_PATH = pathlib.Path("uFast/App/AppText.swift")
SYSTEM_SURFACE_TEXT_PATH = pathlib.Path("LockScreenShared/SystemSurfaceText.swift")
SYSTEM_SURFACE_PATHS = frozenset(
    {
        pathlib.Path("LockScreenShared/ActiveFastActivityProjection.swift"),
        pathlib.Path("LockScreenShared/ActiveFastProjectionFileStore.swift"),
        pathlib.Path("LockScreenShared/ActiveFastWidgetProjection.swift"),
        pathlib.Path("LockScreenShared/LockScreenFastPresentation.swift"),
        pathlib.Path("LockScreenShared/LockScreenWidgetContent.swift"),
        pathlib.Path("LockScreenShared/LockScreenWidgetTimelineSchedule.swift"),
        pathlib.Path("LockScreenShared/SystemSurfaceText.swift"),
        pathlib.Path("LockScreenWidget/Widget/ActiveFastActivityWidget.swift"),
        pathlib.Path("LockScreenWidget/Widget/HomeScreenWidget.swift"),
        pathlib.Path("LockScreenWidget/Widget/UFastLockScreenWidget.swift"),
    }
)
SYSTEM_SURFACE_RESOURCE = pathlib.Path("uFast/Resources/Localizable.xcstrings")
SYSTEM_SURFACE_TARGETS = frozenset({"uFast", "uFastLockScreenWidget"})
MIGRATED_PATHS = frozenset(
    {
        pathlib.Path("uFast/Features/Today/FoodEntryEditor.swift"),
        pathlib.Path("uFast/Features/Today/HydrationEntryEditor.swift"),
        pathlib.Path("uFast/Features/Today/AddDrinkSheet.swift"),
        pathlib.Path("uFast/Features/Today/FoodFavouritePicker.swift"),
        pathlib.Path("uFast/Features/Today/TodaySections.swift"),
        pathlib.Path("uFast/Features/Goal/TodayGoalView.swift"),
        pathlib.Path("uFast/Features/Fasting/DirectHistoricalEntryView.swift"),
        pathlib.Path("uFast/Features/Goal/FastingGoalPicker.swift"),
        pathlib.Path("uFast/Features/Goal/FastingGoalOnboardingView.swift"),
        pathlib.Path("uFast/Features/Goal/PrivacySafetyView.swift"),
        pathlib.Path("uFast/Features/Goal/SettingsSections.swift"),
        pathlib.Path("uFast/Features/Goal/SettingsView.swift"),
        pathlib.Path("uFast/Features/Goal/HydrationFavouriteEditor.swift"),
        pathlib.Path("uFast/Features/Goal/FoodFavouriteEditor.swift"),
        pathlib.Path("uFast/Features/Goal/SettingsFeatureController.swift"),
        pathlib.Path("uFast/Features/Today/InactiveFastView.swift"),
        pathlib.Path("uFast/Features/Today/TodayFeatureController.swift"),
        pathlib.Path("uFast/Persistence/TodayDataProvider.swift"),
        pathlib.Path("uFast/App/AppRootView.swift"),
        pathlib.Path("uFast/App/RootTabView.swift"),
        pathlib.Path("uFast/Features/Foundation/PersistenceUnavailableView.swift"),
        pathlib.Path("uFast/Navigation/AppDestination.swift"),
    }
)
MNT010C_INVENTORY_PATHS = frozenset(
    {
        pathlib.Path("uFast/App/FeatureHosts/HistoryFeatureHost.swift"),
        pathlib.Path("uFast/Application/HistoryPresentationModel.swift"),
        pathlib.Path("uFast/Application/HistoryPresentationModel+Data.swift"),
        pathlib.Path("uFast/Application/HistoryPresentationModel+Motion.swift"),
        pathlib.Path("uFast/Application/HistoryProjectionRefreshBoundary.swift"),
        pathlib.Path("uFast/Persistence/HistoryDataProvider.swift"),
        pathlib.Path("uFast/Domain/ActiveFastPresentation.swift"),
        pathlib.Path("uFast/Domain/TemporalEventGrouping.swift"),
        pathlib.Path("uFast/Features/Foundation/TemporalDateNavigator.swift"),
        pathlib.Path("uFast/Features/Foundation/TemporalHistoryCarousel.swift"),
        pathlib.Path("uFast/Features/Foundation/TemporalRibbonMarks.swift"),
        pathlib.Path("uFast/Features/Foundation/TemporalRibbonSemantics.swift"),
        pathlib.Path("uFast/Features/Foundation/TemporalRibbonView.swift"),
    }
)
HISTORY_GROUPING_COPY_PATHS = frozenset(
    {pathlib.Path("uFast/Domain/TemporalEventGrouping.swift")}
)
HISTORY_GROUPING_COPY_LITERALS = frozenset(
    {"food event", "food events", "drink", "drinks"}
)
HISTORY_INDIRECT_FORMATTER_PATHS = frozenset(
    {
        pathlib.Path("uFast/Features/Fasting/HistoryRows.swift"),
        pathlib.Path("uFast/Features/Foundation/TemporalRibbonSemantics.swift"),
    }
)
LEGACY_HISTORY_FORMATTERS = frozenset({"ActiveElapsedTimeFormatter", "ElapsedTimeFormatter"})
EXCEPTION_MARKER = "localization-exception:"
USER_FACING_CALLS = frozenset(
    {
        "Text",
        "Label",
        "Button",
        "Section",
        "TextField",
        "DatePicker",
        "Picker",
        "ProgressView",
        "LabeledContent",
        "UFastSectionHeading",
        "navigationTitle",
        "alert",
        "accessibilityLabel",
        "accessibilityHint",
        "accessibilityValue",
    }
)
NON_COPY_ARGUMENT_LABELS = frozenset({"systemImage", "systemName"})
COPY_ASSIGNMENT_NAMES = frozenset(
    {
        "accessibilityLabel",
        "placeholder",
        "saveError",
        "deleteError",
        "startError",
        "endError",
        "liveActivityStatus",
    }
)
CATALOG_METADATA_ONLY_KEYS = frozenset()


class LocalizationCheckError(RuntimeError):
    """A localization catalog or changed-source contract violation."""


class SwiftToken(NamedTuple):
    kind: str
    value: str
    line: int


def _added_lines(root: pathlib.Path, relative_path: pathlib.Path) -> list[tuple[int, str]]:
    path = root / relative_path
    status = subprocess.run(
        ["git", "status", "--short", "--", relative_path.as_posix()],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    if status.startswith("??"):
        return list(enumerate(path.read_text(encoding="utf-8").splitlines(), start=1))

    diff = subprocess.run(
        ["git", "diff", "HEAD", "--unified=0", "--", relative_path.as_posix()],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    added: list[tuple[int, str]] = []
    line_number = 0
    for line in diff.splitlines():
        if line.startswith("@@"):
            match = re.search(r"\+(\d+)(?:,(\d+))?", line)
            line_number = int(match.group(1)) - 1 if match else line_number
        elif line.startswith("+") and not line.startswith("+++"):
            line_number += 1
            added.append((line_number, line[1:]))
        elif not line.startswith("-"):
            line_number += 1
    return added


def _swift_tokens(source: str) -> list[SwiftToken]:
    tokens: list[SwiftToken] = []
    index = 0
    line = 1
    while index < len(source):
        character = source[index]
        if character.isspace():
            if character == "\n":
                line += 1
            index += 1
            continue
        if source.startswith("//", index):
            newline = source.find("\n", index)
            if newline == -1:
                break
            index = newline + 1
            line += 1
            continue
        if source.startswith("/*", index):
            index += 2
            depth = 1
            while index < len(source) and depth:
                if source.startswith("/*", index):
                    depth += 1
                    index += 2
                elif source.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    if source[index] == "\n":
                        line += 1
                    index += 1
            continue
        if source.startswith('"""', index):
            start_line = line
            index += 3
            value_start = index
            while index < len(source) and not source.startswith('"""', index):
                if source[index] == "\n":
                    line += 1
                index += 1
            value = source[value_start:index]
            index = min(index + 3, len(source))
            tokens.append(SwiftToken("string", value, start_line))
            continue
        if character == '"':
            start_line = line
            index += 1
            value_start = index
            while index < len(source):
                if source[index] == "\\":
                    index += 2
                    continue
                if source[index] == '"':
                    break
                if source[index] == "\n":
                    line += 1
                index += 1
            value = source[value_start:index]
            index = min(index + 1, len(source))
            tokens.append(SwiftToken("string", value, start_line))
            continue
        if character.isalpha() or character == "_":
            start = index
            index += 1
            while index < len(source) and (source[index].isalnum() or source[index] == "_"):
                index += 1
            tokens.append(SwiftToken("identifier", source[start:index], line))
            continue
        tokens.append(SwiftToken("punctuation", character, line))
        index += 1
    return tokens


def app_text_keys(source: str) -> set[str]:
    """Return every literal key expression passed as the first resource argument.

    AppText uses ternaries for related resources, so this deliberately scans the
    token stream instead of assuming the first argument begins with a string.
    A resource key must remain an explicit static literal (or a choice between
    explicit literals); dynamic key construction is not part of this boundary.
    """
    tokens = _swift_tokens(source)
    keys: set[str] = set()

    for index, token in enumerate(tokens):
        if token.kind != "identifier" or token.value != "resource":
            continue
        if index and tokens[index - 1].kind == "identifier" and tokens[index - 1].value == "func":
            continue
        if index + 1 >= len(tokens) or tokens[index + 1].value != "(":
            continue

        depth = 1
        first_argument: list[SwiftToken] = []
        cursor = index + 2
        while cursor < len(tokens) and depth:
            current = tokens[cursor]
            if current.value in {"(", "[", "{"}:
                depth += 1
            elif current.value in {")", "]", "}"}:
                depth -= 1
            elif current.value == "," and depth == 1:
                break
            if depth:
                first_argument.append(current)
            cursor += 1

        strings = [candidate for candidate in first_argument if candidate.kind == "string"]
        question_marks = [
            candidate for candidate in first_argument if candidate.value == "?"
        ]
        colons = [candidate for candidate in first_argument if candidate.value == ":"]
        is_direct_literal = len(first_argument) == 1 and len(strings) == 1
        is_simple_conditional = (
            len(question_marks) == 1
            and len(colons) == 1
            and len(strings) == 2
            and question_marks[0] in first_argument
            and colons[0] in first_argument
            and first_argument.index(question_marks[0]) < first_argument.index(strings[0])
            < first_argument.index(colons[0]) < first_argument.index(strings[1])
            and first_argument.index(strings[0]) == first_argument.index(question_marks[0]) + 1
            and first_argument.index(strings[1]) == first_argument.index(colons[0]) + 1
        )
        if not (is_direct_literal or is_simple_conditional):
            raise LocalizationCheckError(
                f"resource call on AppText.swift:{token.line} must use a literal key or simple literal-key conditional"
            )
        invalid = [key.value for key in strings if not re.fullmatch(r"[a-z0-9.-]+", key.value)]
        if invalid:
            raise LocalizationCheckError(
                f"resource call on AppText.swift:{token.line} has invalid catalog key literals: "
                + ", ".join(invalid)
            )
        keys.update(key.value for key in strings)

    return keys


def plural_catalog_keys(strings: dict[str, object]) -> set[str]:
    """Derive the complete plural contract from the catalog itself."""
    plural_keys: set[str] = set()
    for key, entry in strings.items():
        if not isinstance(entry, dict):
            continue
        plural = (
            entry.get("localizations", {})
            .get("en", {})
            .get("variations", {})
            .get("plural")
        )
        if plural is not None:
            plural_keys.add(key)
    return plural_keys


def _line_context(lines: Iterable[tuple[int, str]]) -> tuple[list[SwiftToken], dict[int, str], set[int]]:
    entries = list(lines)
    source = "\n".join(line for _, line in entries)
    line_numbers = [number for number, _ in entries]
    tokens = [
        SwiftToken(token.kind, token.value, line_numbers[token.line - 1])
        for token in _swift_tokens(source)
        if token.line <= len(line_numbers)
    ]
    line_text = dict(entries)
    marker_lines = {
        number for number, line in entries if EXCEPTION_MARKER in line
    }
    return tokens, line_text, marker_lines


def _is_exception(line: int, marker_lines: set[int], *related_lines: int) -> bool:
    return any(
        candidate in marker_lines or candidate - 1 in marker_lines
        for candidate in (line, *related_lines)
    )


def literal_violations(lines: Iterable[tuple[int, str]]) -> list[tuple[int, str]]:
    tokens, line_text, marker_lines = _line_context(lines)
    violations: list[tuple[int, str]] = []
    seen: set[tuple[int, str]] = set()

    def add(line: int) -> None:
        if _is_exception(line, marker_lines):
            return
        violation = (line, line_text.get(line, "").strip())
        if violation not in seen:
            seen.add(violation)
            violations.append(violation)

    assignments: dict[str, int] = {}
    for index, token in enumerate(tokens):
        if token.kind != "identifier" or token.value not in {"let", "var"}:
            continue
        if index + 1 >= len(tokens) or tokens[index + 1].kind != "identifier":
            continue
        name = tokens[index + 1].value
        for candidate_index in range(index + 2, min(index + 16, len(tokens))):
            candidate = tokens[candidate_index]
            if candidate.value in {";", "}"}:
                break
            if candidate.value != "=":
                continue
            if candidate_index + 1 < len(tokens) and tokens[candidate_index + 1].kind == "string":
                assignments[name] = tokens[candidate_index + 1].line
            break

    for index, token in enumerate(tokens):
        if token.kind != "identifier" or token.value not in USER_FACING_CALLS:
            continue
        if index + 1 >= len(tokens) or tokens[index + 1].value != "(":
            continue
        depth = 1
        bracket_depth = 0
        brace_depth = 0
        cursor = index + 2
        while cursor < len(tokens) and depth:
            current = tokens[cursor]
            if current.value == "(":
                depth += 1
            elif current.value == ")":
                depth -= 1
            elif current.value == "[":
                bracket_depth += 1
            elif current.value == "]":
                bracket_depth = max(0, bracket_depth - 1)
            elif current.value == "{":
                brace_depth += 1
            elif current.value == "}":
                brace_depth = max(0, brace_depth - 1)
            elif depth == 1 and bracket_depth == 0 and brace_depth == 0 and current.kind == "string":
                argument_label = (
                    tokens[cursor - 2].value
                    if cursor > index + 3 and tokens[cursor - 1].value == ":"
                    else ""
                )
                if (
                    argument_label not in NON_COPY_ARGUMENT_LABELS
                    and not _is_exception(current.line, marker_lines, token.line)
                ):
                    add(current.line)
            elif (
                depth == 1
                and bracket_depth == 0
                and brace_depth == 0
                and current.kind == "identifier"
            ):
                next_value = tokens[cursor + 1].value if cursor + 1 < len(tokens) else ""
                if current.value in assignments and next_value != ":":
                    assignment_line = assignments[current.value]
                    if not _is_exception(current.line, marker_lines, token.line):
                        add(assignment_line)
                        add(current.line)
            cursor += 1

    for index, token in enumerate(tokens):
        if token.kind != "string" or index < 2:
            continue
        if tokens[index - 1].value != "=":
            continue
        name = tokens[index - 2]
        if name.kind == "identifier" and name.value in COPY_ASSIGNMENT_NAMES:
            add(token.line)
    return violations


def indirect_formatter_violations(lines: Iterable[tuple[int, str]]) -> list[tuple[int, str]]:
    """Reject domain-owned duration formatters at History presentation call sites."""
    violations: list[tuple[int, str]] = []
    for line_number, line in lines:
        if any(f"{formatter}." in line for formatter in LEGACY_HISTORY_FORMATTERS):
            violations.append((line_number, line.strip()))
    return violations


def grouping_copy_violations(lines: Iterable[tuple[int, str]]) -> list[tuple[int, str]]:
    """Reject History group family/count copy in the grouping domain model."""
    violations: list[tuple[int, str]] = []
    for line_number, line in lines:
        if any(f'"{literal}"' in line for literal in HISTORY_GROUPING_COPY_LITERALS):
            violations.append((line_number, line.strip()))
    return violations


def validate_catalog(root: pathlib.Path = ROOT) -> None:
    catalog_path = root / CATALOG_PATH
    app_text_path = root / APP_TEXT_PATH
    if not catalog_path.is_file():
        raise LocalizationCheckError(f"catalog is missing: {catalog_path}")
    if not app_text_path.is_file():
        raise LocalizationCheckError(f"AppText is missing: {app_text_path}")

    try:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise LocalizationCheckError(f"catalog is not valid JSON: {error}") from error
    if catalog.get("sourceLanguage") != "en":
        raise LocalizationCheckError("catalog development language must remain en")
    strings = catalog.get("strings")
    if not isinstance(strings, dict):
        raise LocalizationCheckError("catalog strings object is missing")

    app_keys = app_text_keys(app_text_path.read_text(encoding="utf-8"))
    system_surface_path = root / SYSTEM_SURFACE_TEXT_PATH
    system_surface_keys = (
        app_text_keys(system_surface_path.read_text(encoding="utf-8"))
        if system_surface_path.is_file()
        else set()
    )
    required_keys = app_keys | system_surface_keys
    missing = sorted(required_keys - strings.keys())
    if missing:
        raise LocalizationCheckError(
            "presentation resource keys missing from catalog: " + ", ".join(missing)
        )
    stale = sorted(strings.keys() - required_keys - CATALOG_METADATA_ONLY_KEYS)
    if stale:
        raise LocalizationCheckError("catalog keys missing from AppText: " + ", ".join(stale))

    for key, entry in strings.items():
        localizations = entry.get("localizations", {})
        if set(localizations) - {"en"}:
            raise LocalizationCheckError(f"non-English production localization found for {key}")
        if "en" not in localizations:
            raise LocalizationCheckError(f"English localization is missing for {key}")
    for key in plural_catalog_keys(strings):
        plural = strings.get(key, {}).get("localizations", {}).get("en", {}).get("variations", {}).get("plural")
        if not plural or not {"one", "other"} <= set(plural):
            raise LocalizationCheckError(f"plural one/other forms are missing for {key}")


def _target_section(project: str, target: str) -> str:
    match = re.search(
        rf"(?ms)^  {re.escape(target)}:\n(?P<section>.*?)(?=^  \S|\Z)",
        project,
    )
    if not match:
        raise LocalizationCheckError(f"project target is missing: {target}")
    return match.group("section")


def check_system_surface_target_membership(root: pathlib.Path = ROOT) -> None:
    project_path = root / "project.yml"
    if not project_path.is_file():
        raise LocalizationCheckError(f"project manifest is missing: {project_path}")
    project = project_path.read_text(encoding="utf-8")
    for target in SYSTEM_SURFACE_TARGETS:
        section = _target_section(project, target)
        if "      - path: LockScreenShared" not in section:
            raise LocalizationCheckError(
                f"{target} target is missing LockScreenShared membership"
            )
        if target == "uFastLockScreenWidget":
            resources_match = re.search(
                r"(?ms)^    resources:\n(?P<resources>.*?)(?=^    \S|\Z)",
                section,
            )
            if not resources_match or SYSTEM_SURFACE_RESOURCE.as_posix() not in resources_match.group("resources"):
                raise LocalizationCheckError(
                    "widget target does not explicitly include the shared String Catalog"
                )
        elif SYSTEM_SURFACE_RESOURCE.as_posix() not in section:
            raise LocalizationCheckError(
                "app target does not explicitly include the shared String Catalog"
            )


def check_changed_sources(root: pathlib.Path = ROOT) -> None:
    violations: list[str] = []
    for relative_path in sorted(MIGRATED_PATHS):
        path = root / relative_path
        if not path.is_file():
            continue
        added_lines = {line_number for line_number, _ in _added_lines(root, relative_path)}
        source_lines = enumerate(
            path.read_text(encoding="utf-8").splitlines(),
            start=1,
        )
        for line_number, line in literal_violations(source_lines):
            if line_number in added_lines:
                violations.append(f"{relative_path}:{line_number}: {line}")
    if violations:
        raise LocalizationCheckError(
            "new user-facing literals bypass the AppText catalog:\n" + "\n".join(violations)
        )


def inventory_paths(root: pathlib.Path = ROOT) -> list[pathlib.Path]:
    fasting_paths = sorted((root / "uFast/Features/Fasting").glob("*.swift"))
    explicit_paths = [root / relative_path for relative_path in MNT010C_INVENTORY_PATHS]
    system_surface_paths = [root / relative_path for relative_path in SYSTEM_SURFACE_PATHS]
    return sorted(
        {
            path
            for path in (*fasting_paths, *explicit_paths, *system_surface_paths)
            if path.is_file()
        }
    )


def check_inventory(root: pathlib.Path = ROOT) -> dict[pathlib.Path, list[tuple[int, str]]]:
    inventory: dict[pathlib.Path, list[tuple[int, str]]] = {}
    violations: list[str] = []
    for path in inventory_paths(root):
        lines = list(enumerate(path.read_text(encoding="utf-8").splitlines(), start=1))
        found = literal_violations(lines)
        if path.relative_to(root) in HISTORY_INDIRECT_FORMATTER_PATHS:
            found.extend(indirect_formatter_violations(lines))
        if path.relative_to(root) in HISTORY_GROUPING_COPY_PATHS:
            found.extend(grouping_copy_violations(lines))
        inventory[path] = found
        violations.extend(f"{path.relative_to(root)}:{line}: {text}" for line, text in found)
    if violations:
        raise LocalizationCheckError(
            "MNT-010C History inventory found uncatalogued user-facing literals:\n"
            + "\n".join(violations)
        )
    return inventory


def check(root: pathlib.Path = ROOT) -> None:
    validate_catalog(root)
    check_system_surface_target_membership(root)
    check_changed_sources(root)
    check_inventory(root)


def self_test(root: pathlib.Path = ROOT) -> None:
    check(root)
    with tempfile.TemporaryDirectory(prefix="ufast-localization-") as temporary:
        fixture = pathlib.Path(temporary)
        catalog = fixture / CATALOG_PATH
        app_text = fixture / APP_TEXT_PATH
        catalog.parent.mkdir(parents=True)
        app_text.parent.mkdir(parents=True)
        catalog.write_text(
            json.dumps(
                {
                    "sourceLanguage": "en",
                    "strings": {
                        "sample.copy": {
                            "localizations": {"en": {"stringUnit": {"value": "Sample"}}}
                        },
                        "sample.plural": {
                            "localizations": {
                                "en": {
                                    "variations": {
                                        "plural": {
                                            "one": {"stringUnit": {"value": "%lld item"}},
                                            "other": {"stringUnit": {"value": "%lld items"}},
                                        }
                                    }
                                }
                            }
                        },
                    },
                }
            ),
            encoding="utf-8",
        )
        app_text.write_text(
            'resource("sample.copy", "Sample", "test")\n'
            'resource("sample.plural", "1 item", "test")\n',
            encoding="utf-8",
        )
        validate_catalog(fixture)
        migrated = fixture / next(iter(MIGRATED_PATHS))
        migrated.parent.mkdir(parents=True, exist_ok=True)
        migrated.write_text('Text("Uncatalogued copy")\n', encoding="utf-8")
        violations = literal_violations(enumerate(migrated.read_text().splitlines(), start=1))
        if not violations:
            raise LocalizationCheckError("negative control unexpectedly passed")
        migrated.write_text(
            '// localization-exception: system-provided copy\n'
            'Text("System-provided copy")\n',
            encoding="utf-8",
        )
        if literal_violations(enumerate(migrated.read_text().splitlines(), start=1)):
            raise LocalizationCheckError("documented localization exception was rejected")
        migrated.write_text('saveError = "Uncatalogued copy"\n', encoding="utf-8")
        if not literal_violations(enumerate(migrated.read_text().splitlines(), start=1)):
            raise LocalizationCheckError("assignment negative control unexpectedly passed")
        for formatter in LEGACY_HISTORY_FORMATTERS:
            if not indirect_formatter_violations(
                [(1, f"Text({formatter}.string(from: duration))")]
            ):
                raise LocalizationCheckError(
                    f"indirect formatter negative control unexpectedly passed for {formatter}"
                )
        if indirect_formatter_violations(
            [(1, "HistoryTextFormatting.duration(seconds: duration, resolver: resolve)")]
        ):
            raise LocalizationCheckError("catalog formatter boundary was rejected")
        if not grouping_copy_violations([(1, 'return "food events"')]):
            raise LocalizationCheckError("grouping copy negative control unexpectedly passed")
        if grouping_copy_violations([(1, "textResolver(.historyGroupTitle(count: 2, family: .food))")]):
            raise LocalizationCheckError("catalog group-title boundary was rejected")
    print("localization literal/catalog checker self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--inventory", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.self_test:
            self_test()
        elif arguments.inventory:
            validate_catalog()
            inventory = check_inventory()
            print(
                "MNT-010C localization inventory passed: "
                f"{len(inventory)} files, 0 uncatalogued user-facing literals"
            )
        else:
            check()
            print("localization literal/catalog check passed")
    except (LocalizationCheckError, OSError, subprocess.SubprocessError) as error:
        print(f"localization literal/catalog check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
