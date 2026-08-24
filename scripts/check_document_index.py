#!/usr/bin/env python3
"""Check the current document index and its scoped Markdown links."""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys
import tempfile
from collections.abc import Iterable
from urllib.parse import unquote, urlsplit


ROOT = pathlib.Path(__file__).resolve().parents[1]
INDEX_PATH = pathlib.Path("docs/DOCUMENT_INDEX.md")
ACTIVE_SPRINT_PATH = pathlib.Path("docs/POST_MVP_MAINTAINABILITY_FOLLOW_UP_SPRINT.md")
AUTHORITATIVE_PATHS = (
    pathlib.Path("PRODUCT.md"),
    pathlib.Path("docs/ROADMAP.md"),
    pathlib.Path("BACKLOG.md"),
    pathlib.Path("docs/MVP_SCOPE.md"),
    pathlib.Path("DOMAIN_RULES.md"),
    pathlib.Path("DECISIONS.md"),
    pathlib.Path("docs/ARCHITECTURE.md"),
    pathlib.Path("docs/PERSISTENCE_MIGRATIONS.md"),
    pathlib.Path("AGENTS.md"),
    pathlib.Path("docs/LOCAL_RELEASE_GATES.md"),
)
CURRENT_ENTRY_POINTS = (
    pathlib.Path("README.md"),
    INDEX_PATH,
    *AUTHORITATIVE_PATHS,
    ACTIVE_SPRINT_PATH,
)
STATUS_VOCABULARY = frozenset(
    {"current", "active", "completed", "superseded", "historical"}
)
MARKDOWN_LINK = re.compile(
    r"(?<!!)\[[^\]\n]+\]\(\s*(<[^>\n]+>|[^)\s]+)"
)
ROOT_ROADMAP_REFERENCE = re.compile(r"(?<![\w/])ROADMAP\.md\b")
IGNORED_DIRECTORIES = frozenset({".git", ".derived-data", ".derived-data-device"})
CLASSIFICATION_INVENTORY = {
    pathlib.Path("PRIVACY.md"): "current",
    pathlib.Path("SUPPORT.md"): "current",
    pathlib.Path("UX_STYLE_GUIDE.md"): "current",
    pathlib.Path("docs/TRACKED_BINARY_POLICY.md"): "current",
    pathlib.Path("RELEASE_NOTES.md"): "historical",
    pathlib.Path("docs/AGENTIC_CONFIG_REVIEW_AND_RECOMMENDATIONS.md"): "historical",
    pathlib.Path("docs/APP_STORE_CONNECT_BUILD_10.md"): "historical",
    pathlib.Path("docs/APP_STORE_CONNECT_BUILD_9.md"): "historical",
    pathlib.Path("docs/APP_STORE_RELEASE_READINESS_SPRINT.md"): "superseded",
    pathlib.Path("docs/APP_STORE_RELEASE_READINESS_SPRINT_V2.md"): "superseded",
    pathlib.Path("docs/APP_STORE_RELEASE_READINESS_SPRINT_V3.md"): "superseded",
    pathlib.Path("docs/APP_STORE_SUBMISSION_EXECUTION_PLAN.md"): "superseded",
    pathlib.Path("docs/BF-101_FAST_START_36_HOUR_BOUNDARY_STORY.md"): "active",
    pathlib.Path("docs/BF-102_HISTORY_MIDNIGHT_SEAM_RENDERING_STORY.md"): "active",
    pathlib.Path("docs/CODE_REVIEW_APP_STORE_PACKAGING_STORY.md"): "active",
    pathlib.Path("docs/CODE_REVIEW_PERSISTENCE_INTEGRITY_SPRINT.md"): "active",
    pathlib.Path("docs/CODE_REVIEW_RELEASE_INTEGRITY_STORY.md"): "active",
    pathlib.Path("docs/FAVOURITE_DRINK_MANAGEMENT_STORY.md"): "active",
    pathlib.Path("docs/HISTORY_STREAMING_CONTINUITY_STORY.md"): "active",
    pathlib.Path("docs/HISTORY_TIMELINE_UX_IMPROVEMENT_SPRINT.md"): "active",
    pathlib.Path("docs/LIVE_ACTIVITY_PROGRESS_FRESHNESS_STORY.md"): "active",
    pathlib.Path("docs/LIVE_ACTIVITY_UPDATE_RECOVERY_STORY.md"): "active",
    pathlib.Path("docs/LOCALIZATION_POLICY.md"): "current",
    pathlib.Path("docs/MAINTAINABILITY_HARDENING_STORIES.md"): "completed",
    pathlib.Path("docs/MNT-005_BOUNDARY_QUERY_MEASUREMENTS.md"): "completed",
    pathlib.Path("docs/MNT-008_IDENTITY_SCHEMA_IMPLEMENTATION_STORY.md"): "historical",
    pathlib.Path("docs/MNT-014_ROOT_TAB_ACCESSIBILITY_STORY.md"): "active",
    pathlib.Path("docs/MVP_APP_STORE_RELEASE_PLAN.md"): "historical",
    pathlib.Path("docs/OW-410_INFERRED_FAST_DETECTION_STORY.md"): "active",
    pathlib.Path("docs/OW-411_CALORIC_EVENT_FAST_BOUNDARY_STORY.md"): "active",
    pathlib.Path("docs/OW-L101_LOCK_SCREEN_CONTRACT.md"): "completed",
    pathlib.Path("docs/OW_L105_LUNA_PROMPT.md"): "historical",
    pathlib.Path("docs/OW_L109_APP_REVIEW_NOTES.md"): "historical",
    pathlib.Path("docs/OW_LIVE_ACTIVITY_AUTOMATION_LUNA_PROMPT.md"): "historical",
    pathlib.Path("docs/OW_LIVE_ACTIVITY_AUTOMATION_STORIES.md"): "completed",
    pathlib.Path("docs/OW_LOCK_SCREEN_STORIES.md"): "completed",
    pathlib.Path("docs/PARALLEL_UI_TESTS_CODEX_HANDOFF.md"): "historical",
    pathlib.Path("docs/POST_MVP_MAINTAINABILITY_CODE_REVIEW.md"): "historical",
    pathlib.Path("docs/POST_MVP_MAINTAINABILITY_FOLLOW_UP_SPRINT.md"): "active",
    pathlib.Path("docs/POST_MVP_MAINTAINABILITY_LUNA_PROMPT.md"): "historical",
    pathlib.Path("docs/POST_MVP_MAINTAINABILITY_SPRINT.md"): "completed",
    pathlib.Path("docs/PRIVACY_AUTOMATIC_LIVE_ACTIVITIES.md"): "current",
    pathlib.Path("docs/Personal_Health_Companion_Product_Brief.md"): "historical",
    pathlib.Path("docs/READY_STORIES.md"): "historical",
    pathlib.Path("docs/SLICE_1_5_UX_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_2_TODAY_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_3_11_HISTORY_EVENT_GROUPING_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_3_5_HISTORY_UX_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_3_6_HISTORY_INTERACTION_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_3_7_ANALOG_HISTORY_SCROLL_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_3_8_COUPLED_HISTORY_SCROLL_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_3_9_HISTORY_INTERACTION_POLISH_STORIES.md"): "completed",
    pathlib.Path("docs/SLICE_3_CATCH_UP_STORIES.md"): "completed",
    pathlib.Path("docs/STORY_TEMPLATE.md"): "historical",
    pathlib.Path("docs/SUPPORT_AUTOMATIC_LIVE_ACTIVITIES.md"): "current",
    pathlib.Path("docs/WIDGET_SYSTEM_SURFACE_REVIEW_STORIES.md"): "active",
    pathlib.Path("docs/codex-sprint-workflow.md"): "historical",
    pathlib.Path("docs/story-not-to-forget.md"): "historical",
}
CLASSIFICATION_EXCLUSIONS = frozenset(
    {
        INDEX_PATH,
        pathlib.Path("docs/ROADMAP.md"),
        pathlib.Path("docs/MVP_SCOPE.md"),
        pathlib.Path("docs/ARCHITECTURE.md"),
        pathlib.Path("docs/PERSISTENCE_MIGRATIONS.md"),
        pathlib.Path("docs/LOCAL_RELEASE_GATES.md"),
    }
)


class DocumentIndexError(RuntimeError):
    """A current-document index or scoped-link contract violation."""


def _read(root: pathlib.Path, relative_path: pathlib.Path) -> str:
    path = root / relative_path
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        raise DocumentIndexError(f"could not read {relative_path}: {error}") from error


def _link_targets(text: str) -> Iterable[str]:
    for match in MARKDOWN_LINK.finditer(text):
        target = match.group(1)
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1]
        yield target


def _check_local_link(
    root: pathlib.Path,
    source_relative_path: pathlib.Path,
    target: str,
) -> None:
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or not parsed.path:
        return

    root_path = root.resolve()
    source_path = root / source_relative_path
    target_path = (source_path.parent / unquote(parsed.path)).resolve()
    try:
        target_path.relative_to(root_path)
    except ValueError as error:
        raise DocumentIndexError(
            f"{source_relative_path}: link escapes repository: {target}"
        ) from error
    if not target_path.is_file():
        raise DocumentIndexError(
            f"{source_relative_path}: broken local Markdown link: {target}"
        )


def check_markdown_links(
    root: pathlib.Path = ROOT,
    relative_paths: Iterable[pathlib.Path] = CURRENT_ENTRY_POINTS,
) -> int:
    checked = 0
    for relative_path in relative_paths:
        text = _read(root, relative_path)
        for target in _link_targets(text):
            _check_local_link(root, relative_path, target)
            parsed = urlsplit(target)
            if not parsed.scheme and not parsed.netloc and parsed.path:
                checked += 1
    return checked


def check_authority_map(root: pathlib.Path = ROOT) -> None:
    text = _read(root, INDEX_PATH)
    missing = [
        relative_path.as_posix()
        for relative_path in AUTHORITATIVE_PATHS
        if relative_path.as_posix() not in text
    ]
    if missing:
        raise DocumentIndexError(
            "index is missing settled authority entries: " + ", ".join(missing)
        )

    lower_text = text.lower()
    missing_statuses = [
        status for status in STATUS_VOCABULARY if f"| {status} |" not in lower_text
    ]
    if missing_statuses:
        raise DocumentIndexError(
            "index is missing status vocabulary entries: " + ", ".join(missing_statuses)
        )

    if "mnt-101" not in lower_text or ACTIVE_SPRINT_PATH.name not in text:
        raise DocumentIndexError("index must identify MNT-101 as the active sprint")


def _index_link_target(relative_path: pathlib.Path) -> str:
    if relative_path.parts[0] == "docs":
        return relative_path.name
    return f"../{relative_path.as_posix()}"


def check_document_inventory(
    root: pathlib.Path = ROOT,
    inventory: dict[pathlib.Path, str] = CLASSIFICATION_INVENTORY,
    enforce_document_set: bool = True,
) -> int:
    index_text = _read(root, INDEX_PATH)
    missing_files = sorted(
        relative_path.as_posix()
        for relative_path in inventory
        if not (root / relative_path).is_file()
    )
    if missing_files:
        raise DocumentIndexError(
            "classification inventory names missing documents: " + ", ".join(missing_files)
        )

    unclassified: list[str] = []
    misclassified: list[str] = []
    for relative_path, expected in inventory.items():
        target = _index_link_target(relative_path)
        observed = {
            cells[0].strip().lower()
            for line in index_text.splitlines()
            if line.startswith("|")
            for cells in [line.strip().strip("|").split("|")]
            if len(cells) > 1
            and f"]({target})" in cells[1]
        }
        observed &= STATUS_VOCABULARY
        if not observed:
            unclassified.append(relative_path.as_posix())
        elif observed != {expected}:
            misclassified.append(
                f"{relative_path.as_posix()} expected {expected}, found {sorted(observed)}"
            )

    if enforce_document_set:
        known_docs = {
            path.relative_to(root)
            for path in (root / "docs").glob("*.md")
            if path.is_file()
        }
        known_docs -= CLASSIFICATION_EXCLUSIONS
        inventory_paths = {path for path in inventory if path.parts[0] == "docs"}
        unlisted = sorted(path.as_posix() for path in known_docs - inventory_paths)
        if unlisted:
            unclassified.extend(unlisted)

    if unclassified or misclassified:
        details = []
        if unclassified:
            details.append("unclassified: " + ", ".join(sorted(set(unclassified))))
        if misclassified:
            details.append("misclassified: " + "; ".join(misclassified))
        raise DocumentIndexError("planning/review/support document inventory failed: " + " | ".join(details))
    return len(inventory)


def check_roadmap_references(root: pathlib.Path = ROOT) -> int:
    violations: list[str] = []
    markdown_paths: list[pathlib.Path] = []
    for directory, directories, filenames in os.walk(root):
        directories[:] = [directory for directory in directories if directory not in IGNORED_DIRECTORIES]
        markdown_paths.extend(
            pathlib.Path(directory) / filename
            for filename in filenames
            if filename.endswith(".md")
        )

    for path in sorted(markdown_paths):
        relative_path = path.relative_to(root)
        text = path.read_text(encoding="utf-8")
        matches = ROOT_ROADMAP_REFERENCE.finditer(text)
        invalid_matches = [
            match
            for match in matches
            if not (
                relative_path == INDEX_PATH
                and match.start() > 0
                and text[match.start() - 1] == "("
            )
        ]
        if invalid_matches:
            violations.append(relative_path.as_posix())
    if violations:
        raise DocumentIndexError(
            "root ROADMAP.md references remain in: " + ", ".join(violations)
        )
    return len(markdown_paths)


def check(root: pathlib.Path = ROOT) -> tuple[int, int, int]:
    required_paths = (INDEX_PATH, *AUTHORITATIVE_PATHS, *CURRENT_ENTRY_POINTS)
    missing = sorted(
        {
            relative_path.as_posix()
            for relative_path in required_paths
            if not (root / relative_path).is_file()
        }
    )
    if missing:
        raise DocumentIndexError("required current document is missing: " + ", ".join(missing))
    check_authority_map(root)
    classified_count = check_document_inventory(root)
    checked_links = check_markdown_links(root)
    markdown_count = check_roadmap_references(root)
    return checked_links, markdown_count, classified_count


def _expect_failure(label: str, action) -> None:
    try:
        action()
    except DocumentIndexError:
        print(f"negative control passed: {label}")
    else:
        raise DocumentIndexError(f"negative control unexpectedly passed: {label}")


def self_test(root: pathlib.Path = ROOT) -> None:
    check(root)

    with tempfile.TemporaryDirectory(prefix="ufast-document-index-") as temporary:
        fixture_root = pathlib.Path(temporary)
        readme = fixture_root / "README.md"
        readme.write_text("[missing](missing.md)\n", encoding="utf-8")
        _expect_failure(
            "broken local Markdown link",
            lambda: check_markdown_links(fixture_root, (pathlib.Path("README.md"),)),
        )

        readme.write_text("Root `ROADMAP.md` is not an authority.\n", encoding="utf-8")
        _expect_failure(
            "root roadmap reference",
            lambda: check_roadmap_references(fixture_root),
        )

        index = fixture_root / INDEX_PATH
        index.parent.mkdir(parents=True)
        index.write_text("| Product | PRODUCT.md |\n", encoding="utf-8")
        _expect_failure(
            "incomplete authority map",
            lambda: check_authority_map(fixture_root),
        )

        known_document = pathlib.Path("docs/HISTORY_TIMELINE_UX_IMPROVEMENT_SPRINT.md")
        (fixture_root / known_document).parent.mkdir(parents=True, exist_ok=True)
        (fixture_root / known_document).write_text("# Known planning document\n", encoding="utf-8")
        index.write_text(
            "| Classification | Document |\n"
            "| --- | --- |\n"
            "|  | [History timeline](HISTORY_TIMELINE_UX_IMPROVEMENT_SPRINT.md) |\n",
            encoding="utf-8",
        )
        _expect_failure(
            "known planning document without classification",
            lambda: check_document_inventory(
                fixture_root,
                {known_document: "active"},
                enforce_document_set=False,
            ),
        )

    print("document index checker self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.self_test:
            self_test()
        else:
            checked_links, markdown_count, classified_count = check()
            print(
                "document index check passed: "
                f"{checked_links} local links checked across {markdown_count} Markdown files; "
                f"{classified_count} planning/review/support documents classified"
            )
    except (DocumentIndexError, OSError) as error:
        print(f"document index check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
