#!/usr/bin/env python3
"""Authoritative local release evidence gate.

The normal invocation runs every required local check and writes a manifest only
after every command and the source-bound UI evidence pass.  ``--self-test`` is
deterministic and exercises the negative controls without building or uploading.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST_DEFAULT = ROOT / ".derived-data/release-gate/release-manifest.json"
BUILD_MARKER_NAME = ".release-gate-build.json"
SOURCE_ROOTS = (
    "uFast/",
    "UFastCore/",
    "LockScreenShared/",
    "LockScreenWidget/",
    "LockScreenPrototype/",
    "uFastTests/",
    "UFastCoreTests/",
    "uFastUITests/",
    "scripts/",
)
SOURCE_FILES = {
    "Makefile",
    "project.yml",
    ".swiftlint.yml",
    ".swiftformat",
    ".swiftlint-analyze-baseline.json",
}


class GateError(RuntimeError):
    pass


@dataclass
class CommandResult:
    name: str
    command: list[str]
    exit_code: int
    log_path: pathlib.Path

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "command": self.command,
            "exit_code": self.exit_code,
            "log": str(self.log_path.resolve()),
        }


def parse_unit_aggregate_counts(log_text: str) -> tuple[dict[str, int], dict[str, int]]:
    """Read the aggregate app/core totals from the two test-unit invocations.

    XCTest prints a class-level ``Executed ...`` line before the aggregate
    summary.  The Make target runs the app and core suites as separate
    invocations, each bracketed by an ``All tests`` start marker, so segment
    the combined log first and take the final summary in each segment.
    """

    test_pattern = re.compile(r"Executed (\d+) tests, with (\d+) failures")
    sections = re.split(r"(?=Test Suite 'All tests' started)", log_text)
    summaries: list[tuple[int, int]] = []
    for section in sections:
        if not section.startswith("Test Suite 'All tests' started"):
            continue
        matches = test_pattern.findall(section)
        if matches:
            executed, failures = matches[-1]
            summaries.append((int(executed), int(failures)))
    if len(summaries) != 2:
        raise GateError(
            "unit test evidence did not contain exactly two aggregate app/core "
            f"XCTest counts: found {len(summaries)} invocations"
        )
    (app_executed, app_failures), (core_executed, core_failures) = summaries
    return (
        {"executed": app_executed, "failures": app_failures},
        {"executed": core_executed, "failures": core_failures},
    )


def tracked_source_paths() -> list[pathlib.Path]:
    completed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    paths: list[pathlib.Path] = []
    for raw in completed.stdout.splitlines():
        relative = pathlib.Path(raw)
        if relative.name in {"", ".DS_Store"}:
            continue
        if relative.as_posix() not in SOURCE_FILES and not any(
            raw.startswith(prefix) for prefix in SOURCE_ROOTS
        ):
            continue
        absolute = ROOT / relative
        if absolute.is_file():
            paths.append(relative)
    return sorted(set(paths), key=lambda path: path.as_posix())


def file_digest(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    if path.is_file():
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    elif path.is_dir():
        for child in sorted(path.rglob("*")):
            if child.is_file():
                digest.update(child.relative_to(path).as_posix().encode())
                digest.update(b"\0")
                with child.open("rb") as handle:
                    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                        digest.update(chunk)
    else:
        raise GateError(f"cannot hash missing artifact: {path}")
    return digest.hexdigest()


def content_source_freeze_id() -> str:
    digest = hashlib.sha256()
    for relative in tracked_source_paths():
        digest.update(relative.as_posix().encode())
        digest.update(b"\0")
        with (ROOT / relative).open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        digest.update(b"\0")
    return f"sha256:{digest.hexdigest()}"


def git_status() -> list[str]:
    completed = subprocess.run(
        ["git", "status", "--short"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in completed.stdout.splitlines() if line]


def commit_sha() -> str:
    completed = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def project_version() -> tuple[str, str]:
    source = (ROOT / "project.yml").read_text(encoding="utf-8")
    version_match = re.search(r"^\s*MARKETING_VERSION:\s*(\S+)\s*$", source, re.MULTILINE)
    build_match = re.search(r"^\s*CURRENT_PROJECT_VERSION:\s*(\S+)\s*$", source, re.MULTILINE)
    if not version_match or not build_match:
        raise GateError("project.yml is missing MARKETING_VERSION or CURRENT_PROJECT_VERSION")
    return version_match.group(1), build_match.group(1)


def tool_versions() -> dict[str, str]:
    commands = {
        "xcodebuild": [os.environ.get("XCODEBUILD_BIN", "xcodebuild"), "-version"],
        "xcodegen": [os.environ.get("XCODEGEN_BIN", "xcodegen"), "--version"],
        "swiftlint": ["swiftlint", "version"],
        "swiftformat": ["swiftformat", "--version"],
        "python": [sys.executable, "--version"],
    }
    values: dict[str, str] = {}
    for name, command in commands.items():
        try:
            completed = subprocess.run(
                command,
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            values[name] = (completed.stdout or completed.stderr).strip().splitlines()[0]
        except (OSError, subprocess.CalledProcessError, IndexError) as error:
            values[name] = f"unavailable: {error}"
    return values


def result_metadata_path(result: pathlib.Path) -> pathlib.Path:
    return pathlib.Path(f"{result}.source-freeze.json")


def validate_ui_binding(result: pathlib.Path, expected_id: str) -> dict[str, Any]:
    if not result.is_dir():
        raise GateError(f"UI evidence result is missing: {result}")
    metadata_path = result_metadata_path(result)
    if not metadata_path.is_file():
        raise GateError(f"UI evidence is unbound: missing {metadata_path}")
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise GateError(f"UI evidence metadata is invalid: {metadata_path}: {error}") from error
    if metadata.get("content_source_freeze_id") != expected_id:
        raise GateError(
            "UI evidence source-freeze mismatch: "
            f"expected {expected_id}, got {metadata.get('content_source_freeze_id')!r}"
        )
    if metadata.get("result_sha256") != file_digest(result):
        raise GateError(f"UI evidence is stale or modified after capture: {result}")
    if metadata.get("worker_count") != 4:
        raise GateError(f"UI evidence worker count is not four: {metadata.get('worker_count')!r}")
    return {"path": str(result.resolve()), "metadata": str(metadata_path.resolve()), **metadata}


def run_command(
    name: str,
    command: list[str],
    log_directory: pathlib.Path,
    results: list[CommandResult],
    *,
    environment: dict[str, str] | None = None,
) -> None:
    log_path = log_directory / f"{len(results) + 1:02d}-{name}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8") as log:
        log.write(f"command: {json.dumps(command)}\n")
        completed = subprocess.run(
            command,
            cwd=ROOT,
            env=environment,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
        log.write(f"underlying_exit_code: {completed.returncode}\n")
    result = CommandResult(name, command, completed.returncode, log_path)
    results.append(result)
    print(f"{name}: exit {completed.returncode} (log: {log_path})")
    if completed.returncode != 0:
        raise GateError(f"release gate command failed: {name} (exit {completed.returncode})")


def built_entitlement_candidates(build_root: pathlib.Path) -> tuple[list[pathlib.Path], list[pathlib.Path]]:
    intermediate = build_root / "Build/Intermediates.noindex"
    return (
        sorted(intermediate.rglob("uFast.app-Simulated.xcent")),
        sorted(intermediate.rglob("uFast Lock Screen Widget.appex-Simulated.xcent")),
    )


def write_build_marker(build_root: pathlib.Path) -> pathlib.Path:
    """Record the exact xcent paths and digests emitted by an isolated build."""

    app_candidates, widget_candidates = built_entitlement_candidates(build_root)
    if len(app_candidates) != 1 or len(widget_candidates) != 1:
        raise GateError(
            "built entitlement inputs are required exactly once: "
            f"app={len(app_candidates)} widget={len(widget_candidates)}"
        )
    marker = build_root / BUILD_MARKER_NAME
    marker.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "app": {
            "path": app_candidates[0].relative_to(build_root).as_posix(),
            "sha256": file_digest(app_candidates[0]),
        },
        "widget": {
            "path": widget_candidates[0].relative_to(build_root).as_posix(),
            "sha256": file_digest(widget_candidates[0]),
        },
    }
    marker.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return marker


def resolve_newly_built_entitlements(build_root: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path]:
    """Resolve xcent inputs from a unique build root and its post-build digest marker.

    The gate uses a new isolated derived-data directory for every run.  The
    marker is written only after that build returns and binds both case-correct
    xcent inputs to their exact content, so repeated incremental builds do not
    depend on filesystem mtime resolution.
    """

    marker = build_root / BUILD_MARKER_NAME
    if not marker.is_file():
        raise GateError(f"built entitlement freshness marker is missing: {marker}")
    try:
        payload = json.loads(marker.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise GateError(f"built entitlement freshness marker is invalid: {marker}: {error}") from error
    app_candidates, widget_candidates = built_entitlement_candidates(build_root)
    if len(app_candidates) != 1 or len(widget_candidates) != 1:
        raise GateError(
            "built entitlement inputs are required exactly once: "
            f"app={len(app_candidates)} widget={len(widget_candidates)}"
        )
    resolved: list[pathlib.Path] = []
    for kind, candidates in (("app", app_candidates), ("widget", widget_candidates)):
        expected = payload.get(kind)
        if not isinstance(expected, dict):
            raise GateError(f"built entitlement freshness marker is missing {kind} identity")
        path = candidates[0]
        if expected.get("path") != path.relative_to(build_root).as_posix():
            raise GateError(f"built {kind} entitlement path does not match its freshness marker")
        if expected.get("sha256") != file_digest(path):
            raise GateError(f"built {kind} entitlement changed after its freshness marker was written")
        resolved.append(path)
    return resolved[0], resolved[1]


def entitlement_resolver_self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="uFast-entitlement-resolver-") as directory:
        root = pathlib.Path(directory)

        def seed(name: str) -> pathlib.Path:
            build_root = root / name / "isolated-build"
            app = build_root / "Build/Intermediates.noindex/app/uFast.app-Simulated.xcent"
            widget = build_root / (
                "Build/Intermediates.noindex/widget/"
                "uFast Lock Screen Widget.appex-Simulated.xcent"
            )
            app.parent.mkdir(parents=True, exist_ok=True)
            widget.parent.mkdir(parents=True, exist_ok=True)
            app.write_bytes(b"app entitlement fixture")
            widget.write_bytes(b"widget entitlement fixture")
            write_build_marker(build_root)
            return build_root

        valid = seed("valid")
        resolve_newly_built_entitlements(valid)
        resolve_newly_built_entitlements(valid)

        missing = seed("missing")
        (missing / "Build/Intermediates.noindex/app/uFast.app-Simulated.xcent").unlink()
        try:
            resolve_newly_built_entitlements(missing)
        except GateError:
            pass
        else:
            raise GateError("entitlement resolver accepted a missing app fixture")

        stale = seed("stale")
        (stale / "Build/Intermediates.noindex/app/uFast.app-Simulated.xcent").write_bytes(
            b"changed after build marker"
        )
        try:
            resolve_newly_built_entitlements(stale)
        except GateError:
            pass
        else:
            raise GateError("entitlement resolver accepted a stale digest fixture")

        duplicate = seed("duplicate")
        duplicate_app = duplicate / (
            "Build/Intermediates.noindex/duplicate/uFast.app-Simulated.xcent"
        )
        duplicate_app.parent.mkdir(parents=True, exist_ok=True)
        duplicate_app.write_bytes(b"duplicate app entitlement fixture")
        try:
            resolve_newly_built_entitlements(duplicate)
        except GateError:
            pass
        else:
            raise GateError("entitlement resolver accepted a duplicate app fixture")
    print("Built entitlement resolver self-test passed: repeated valid, missing, stale, duplicate")


def write_ui_binding(
    result: pathlib.Path,
    *,
    label: str,
    worker_count: int,
    captured_id: str | None = None,
    output: pathlib.Path | None = None,
) -> pathlib.Path:
    metadata_path = output or result_metadata_path(result)
    current_id = content_source_freeze_id()
    if captured_id is not None and captured_id != current_id:
        raise GateError(
            "source changed while UI evidence was running: "
            f"captured {captured_id}, current {current_id}"
        )
    metadata = {
        "metadata_version": 1,
        "content_source_freeze_id": captured_id or current_id,
        "source_freeze_id": captured_id or current_id,
        "source_freeze_label": label,
        "worker_count": worker_count,
        "result_sha256": file_digest(result),
        "result_path": str(result.resolve()),
    }
    metadata_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return metadata_path


def copy_current_artifact(source: pathlib.Path, destination: pathlib.Path) -> pathlib.Path:
    if not source.exists():
        raise GateError(f"current-run artifact is missing: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, destination)
    else:
        shutil.copy2(source, destination)
    return destination


def copy_current_ui_evidence(
    source: pathlib.Path,
    destination: pathlib.Path,
    expected_id: str,
) -> tuple[pathlib.Path, dict[str, Any]]:
    original = validate_ui_binding(source, expected_id)
    copy_current_artifact(source, destination)
    source_metadata = json.loads(
        result_metadata_path(source).read_text(encoding="utf-8")
    )
    source_metadata["result_path"] = str(destination.resolve())
    source_metadata["result_sha256"] = file_digest(destination)
    result_metadata_path(destination).write_text(
        json.dumps(source_metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    copied = validate_ui_binding(destination, expected_id)
    copied["source_result_path"] = original["path"]
    return destination, copied


def run_gate(
    ui_result: pathlib.Path,
    manifest_path: pathlib.Path,
    *,
    injected_failure: str | None = None,
) -> int:
    if manifest_path.exists():
        manifest_path.unlink()
    if injected_failure in {"version", "privacy", "ui"}:
        raise GateError(f"injected {injected_failure} orchestration failure")
    status = git_status()
    source_id = content_source_freeze_id()
    initial_commit = commit_sha()
    version, build = project_version()
    run_directory = manifest_path.parent / (
        f"run-{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}-"
        f"{os.getpid()}-{time.time_ns()}"
    )
    run_directory.mkdir(parents=True, exist_ok=True)
    current_ui_result, metadata = copy_current_ui_evidence(
        ui_result, run_directory / "ui-result.xcresult", source_id
    )
    build_root = run_directory / "build"
    results: list[CommandResult] = []
    derived_data_argument = f"DERIVED_DATA={build_root}"
    run_command(
        "build",
        ["make", "CODE_SIGNING_ALLOWED=YES", derived_data_argument, "build"],
        run_directory,
        results,
    )
    write_build_marker(build_root)
    built_app, built_widget = resolve_newly_built_entitlements(build_root)
    local_only_environment = os.environ.copy()
    local_only_environment["BUILT_APP_ENTITLEMENTS"] = str(built_app)
    local_only_environment["BUILT_WIDGET_ENTITLEMENTS"] = str(built_widget)
    commands = [
        ("test-unit", ["make", derived_data_argument, "test-unit"]),
        ("lint", ["make", "lint"]),
        ("analyze", ["make", "analyze"]),
        ("verify-local-only", ["make", "verify-local-only"], local_only_environment),
        ("verify-release-versions", ["make", "verify-release-versions"]),
        ("verify-ui-verifier", ["make", "verify-ui-verifier"]),
        ("verify-ui-result", ["make", "verify-ui-result", f"UI_XCRESULT={current_ui_result}"]),
    ]
    for entry in commands:
        name, command, *environment = entry
        run_command(
            name,
            command,
            run_directory,
            results,
            environment=environment[0] if environment else None,
        )

    test_counts: dict[str, dict[str, int]] = {}
    unit_result = next(result for result in results if result.name == "test-unit")
    app_counts, core_counts = parse_unit_aggregate_counts(
        unit_result.log_path.read_text(encoding="utf-8", errors="replace")
    )
    test_counts["app_units"] = app_counts
    test_counts["core_units"] = core_counts

    ui_result_command = next(result for result in results if result.name == "verify-ui-result")
    ui_match = re.search(
        r"UI xcresult verified: (\d+) tests exactly once, (\d+) skipped, (\d+) worker clones",
        ui_result_command.log_path.read_text(encoding="utf-8", errors="replace"),
    )
    if ui_match is None:
        raise GateError("UI verifier evidence did not contain its deterministic test count")
    test_counts["ui"] = {
        "executed": int(ui_match.group(1)),
        "skipped": int(ui_match.group(2)),
        "worker_clones": int(ui_match.group(3)),
    }
    test_result_root = build_root / "Logs/Test"
    app_test_results = sorted(
        test_result_root.glob("Test-uFast-*.xcresult"),
        key=lambda path: path.stat().st_mtime_ns,
    )
    core_test_results = sorted(
        test_result_root.glob("Test-UFastCore-*.xcresult"),
        key=lambda path: path.stat().st_mtime_ns,
    )
    if not app_test_results or not core_test_results:
        raise GateError("current-run unit test result artifacts are missing from the isolated Logs/Test directory")
    app_test_result = app_test_results[-1]
    core_test_result = core_test_results[-1]
    analyzer_source = ROOT / ".derived-data/logs/swiftlint-analyze-xcodebuild.log"
    analyzer_log = copy_current_artifact(analyzer_source, run_directory / "analyzer.log")
    current_run_artifacts = {
        "app_unit_log": unit_result.log_path,
        "core_unit_log": unit_result.log_path,
        "app_unit_xcresult": app_test_result,
        "core_unit_xcresult": core_test_result,
        "analyzer_log": analyzer_log,
        "ui_verifier_log": ui_result_command.log_path,
        "ui_result": current_ui_result,
    }
    artifact_digests = {}
    for name, artifact in current_run_artifacts.items():
        if not artifact.exists():
            raise GateError(f"current-run artifact is missing: {artifact}")
        artifact_digests[name] = file_digest(artifact)

    versions = tool_versions()

    # Re-read every source-freeze input immediately before writing the manifest.
    # A command that edits source, project metadata, or the analyzer baseline
    # invalidates the candidate rather than producing a stale passing manifest.
    final_source_id = content_source_freeze_id()
    final_commit = commit_sha()
    final_status = git_status()
    final_version, final_build = project_version()
    if final_source_id != source_id:
        raise GateError("source content changed while the release gate was running")
    if final_commit != initial_commit:
        raise GateError("commit SHA changed while the release gate was running")
    if final_status != status:
        raise GateError("worktree status changed while the release gate was running")
    if (final_version, final_build) != (version, build):
        raise GateError("project version/build changed while the release gate was running")
    baseline = ROOT / ".swiftlint-analyze-baseline.json"

    manifest = {
        "manifest_version": 1,
        "status": "passed",
        "content_source_freeze_id": final_source_id,
        "source_freeze_id": final_source_id,
        "source_freeze": {
            "content_source_freeze_id": final_source_id,
            "commit_sha": final_commit,
            "worktree_status": final_status,
            "version": final_version,
            "build": final_build,
            "analyze_baseline_sha256": file_digest(baseline),
            "analyze_baseline_path": str(baseline.resolve()),
        },
        "commit_sha": final_commit,
        "worktree": {
            "state": "clean" if not final_status else "dirty",
            "status": final_status,
        },
        "upload_authorized": not final_status,
        "version": final_version,
        "build": final_build,
        "tool_versions": versions,
        "commands": [result.as_dict() for result in results],
        "test_counts": test_counts,
        "ui_evidence": metadata,
        "artifacts": {
            "manifest": str(manifest_path.resolve()),
            "logs": str(run_directory.resolve()),
            "app_unit_log": str(unit_result.log_path.resolve()),
            "core_unit_log": str(unit_result.log_path.resolve()),
            "app_unit_xcresult": str(app_test_result.resolve()),
            "core_unit_xcresult": str(core_test_result.resolve()),
            "analyzer_log": str(analyzer_log.resolve()),
            "ui_verifier_log": str(ui_result_command.log_path.resolve()),
            "ui_result": str(current_ui_result.resolve()),
        },
        "artifact_digests": artifact_digests,
    }
    assert_manifest_valid(manifest)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Release gate passed: {manifest_path}")
    if status:
        print("Candidate manifest is NOT upload-authorised because the tree is dirty.")
    return 0


def assert_manifest_valid(manifest: dict[str, Any]) -> None:
    if manifest.get("status") != "passed":
        raise GateError("manifest is not a passing manifest")
    if not str(manifest.get("content_source_freeze_id", "")).startswith("sha256:"):
        raise GateError("manifest has no content source-freeze identity")
    if manifest.get("source_freeze_id") != manifest.get("content_source_freeze_id"):
        raise GateError("manifest source-freeze identities do not agree")
    source_freeze = manifest.get("source_freeze")
    if not isinstance(source_freeze, dict):
        raise GateError("manifest has no source-freeze snapshot")
    for key in (
        "content_source_freeze_id",
        "commit_sha",
        "worktree_status",
        "version",
        "build",
        "analyze_baseline_sha256",
        "analyze_baseline_path",
    ):
        if key not in source_freeze:
            raise GateError(f"manifest source-freeze snapshot is missing {key}")
    if source_freeze["content_source_freeze_id"] != manifest["content_source_freeze_id"]:
        raise GateError("manifest source-freeze snapshot does not match content identity")
    if not re.fullmatch(r"[0-9a-f]{40}", str(manifest.get("commit_sha", ""))):
        raise GateError("manifest has no commit SHA")
    if source_freeze["commit_sha"] != manifest["commit_sha"]:
        raise GateError("manifest source-freeze snapshot does not match commit SHA")
    if not isinstance(manifest.get("tool_versions"), dict) or not manifest["tool_versions"]:
        raise GateError("manifest has no tool versions")
    commands = manifest.get("commands")
    if not isinstance(commands, list) or any(command.get("exit_code") != 0 for command in commands):
        raise GateError("manifest contains a failed underlying command")
    test_counts = manifest.get("test_counts")
    if not isinstance(test_counts, dict) or any(
        key not in test_counts for key in ("app_units", "core_units", "ui")
    ):
        raise GateError("manifest does not record distinct app, core, and UI test counts")
    ui = manifest.get("ui_evidence")
    if not isinstance(ui, dict) or not ui.get("content_source_freeze_id"):
        raise GateError("manifest has no bound UI evidence")
    artifacts = manifest.get("artifacts")
    required_artifacts = {
        "manifest",
        "logs",
        "app_unit_log",
        "core_unit_log",
        "app_unit_xcresult",
        "core_unit_xcresult",
        "analyzer_log",
        "ui_verifier_log",
        "ui_result",
    }
    if not isinstance(artifacts, dict) or not required_artifacts.issubset(artifacts):
        raise GateError("manifest is missing stable command or result artifacts")
    artifact_digests = manifest.get("artifact_digests")
    digest_keys = {
        "app_unit_log",
        "core_unit_log",
        "app_unit_xcresult",
        "core_unit_xcresult",
        "analyzer_log",
        "ui_verifier_log",
        "ui_result",
    }
    if not isinstance(artifact_digests, dict) or not digest_keys.issubset(artifact_digests):
        raise GateError("manifest is missing current-run artifact digests")
    for key in digest_keys:
        artifact = pathlib.Path(str(artifacts[key]))
        if not artifact.exists() or file_digest(artifact) != artifact_digests[key]:
            raise GateError(f"manifest artifact is missing or digest-mismatched: {key}")
    if manifest.get("worktree", {}).get("state") == "dirty" and manifest.get("upload_authorized"):
        raise GateError("dirty manifest cannot be upload-authorised")


def validate_version_fixture(values: dict[str, str]) -> None:
    if values.get("app") != values.get("widget"):
        raise GateError("version/build parity mismatch")


def validate_privacy_fixture(path: pathlib.Path) -> None:
    if not path.is_file():
        raise GateError("privacy declaration is missing")
    with path.open("rb") as handle:
        value = plistlib.load(handle)
    if set(value) != {"NSPrivacyAccessedAPITypes"}:
        raise GateError("privacy declaration has unexpected keys")


def positive_manifest_fixture(root: pathlib.Path) -> dict[str, Any]:
    """Return a complete passing manifest fixture for the manifest validator."""

    content_id = "sha256:positive-fixture"
    artifact_names = (
        "manifest",
        "logs",
        "app_unit_log",
        "core_unit_log",
        "app_unit_xcresult",
        "core_unit_xcresult",
        "analyzer_log",
        "ui_verifier_log",
        "ui_result",
    )
    artifact_paths = {key: root / f"{key}.artifact" for key in artifact_names}
    for key, path in artifact_paths.items():
        path.write_text(f"positive {key}\n", encoding="utf-8")
    current_artifact_names = (
        "app_unit_log",
        "core_unit_log",
        "app_unit_xcresult",
        "core_unit_xcresult",
        "analyzer_log",
        "ui_verifier_log",
        "ui_result",
    )
    return {
        "manifest_version": 1,
        "status": "passed",
        "content_source_freeze_id": content_id,
        "source_freeze_id": content_id,
        "source_freeze": {
            "content_source_freeze_id": content_id,
            "commit_sha": "0123456789abcdef0123456789abcdef01234567",
            "worktree_status": [],
            "version": "1.0.0",
            "build": "10",
            "analyze_baseline_sha256": "a" * 64,
            "analyze_baseline_path": str((root / ".swiftlint-analyze-baseline.json").resolve()),
        },
        "commit_sha": "0123456789abcdef0123456789abcdef01234567",
        "worktree": {"state": "clean", "status": []},
        "upload_authorized": True,
        "version": "1.0.0",
        "build": "10",
        "tool_versions": {"python": "Python 3"},
        "commands": [{"name": "fixture", "exit_code": 0}],
        "test_counts": {
            "app_units": {"executed": 364, "failures": 0},
            "core_units": {"executed": 14, "failures": 0},
            "ui": {"executed": 105, "skipped": 0, "worker_clones": 4},
        },
        "ui_evidence": {"content_source_freeze_id": content_id},
        "artifacts": {key: str(path.resolve()) for key, path in artifact_paths.items()},
        "artifact_digests": {
            key: file_digest(artifact_paths[key]) for key in current_artifact_names
        },
    }


def unit_count_parser_self_test() -> None:
    """Class summaries must not be mistaken for the app/core aggregates."""

    fixture = """
Test Suite 'All tests' started at 2026-08-20 11:00:00.000
Test Suite 'AppClassTests' started at 2026-08-20 11:00:00.001
Executed 9 tests, with 0 failures (0 unexpected) in 0.1 seconds
Test Suite 'AppClassTests' passed at 2026-08-20 11:00:00.010
Executed 364 tests, with 0 failures (0 unexpected) in 12.0 seconds
Test Suite 'All tests' passed at 2026-08-20 11:00:12.000
Test Suite 'All tests' started at 2026-08-20 11:00:13.000
Test Suite 'CoreClassTests' started at 2026-08-20 11:00:13.001
Executed 4 tests, with 0 failures (0 unexpected) in 0.1 seconds
Test Suite 'CoreClassTests' passed at 2026-08-20 11:00:13.010
Executed 14 tests, with 0 failures (0 unexpected) in 1.0 seconds
Test Suite 'All tests' passed at 2026-08-20 11:00:14.000
"""
    app_counts, core_counts = parse_unit_aggregate_counts(fixture)
    if app_counts != {"executed": 364, "failures": 0}:
        raise GateError(f"unit parser selected the wrong app summary: {app_counts}")
    if core_counts != {"executed": 14, "failures": 0}:
        raise GateError(f"unit parser selected the wrong core summary: {core_counts}")
    print("Unit aggregate parser self-test passed: app=364/core=14")


def assert_gate_failure_without_manifest(
    manifest_path: pathlib.Path,
    name: str,
    action: Any,
) -> None:
    """A failed gate preflight must leave no passing manifest behind."""

    manifest_path.unlink(missing_ok=True)
    try:
        action()
    except (GateError, OSError, plistlib.InvalidFileException, ValueError):
        pass
    else:
        raise GateError(f"release gate self-test accepted invalid {name} fixture")
    if manifest_path.exists():
        raise GateError(f"release gate emitted a manifest for invalid {name} fixture")


def upload_transaction_self_test() -> None:
    """Exercise the actual upload wrapper against deterministic command boundaries."""

    script_source = ROOT / "scripts/upload_testflight.sh"
    export_options_source = ROOT / "scripts/testflight-export-options.plist"
    if not script_source.is_file() or not export_options_source.is_file():
        raise GateError("upload transaction self-test is missing its script or export fixture")

    def write_executable(path: pathlib.Path, contents: str) -> None:
        path.write_text(contents, encoding="utf-8")
        path.chmod(0o755)

    def create_fixture(root: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path, pathlib.Path, pathlib.Path]:
        (root / "scripts").mkdir(parents=True)
        script = root / "scripts/upload_testflight.sh"
        shutil.copy2(script_source, script)
        script.chmod(0o755)
        shutil.copy2(export_options_source, root / "scripts/testflight-export-options.plist")
        (root / "project.yml").write_text(
            "MARKETING_VERSION: 1.0.0\nCURRENT_PROJECT_VERSION: 10\n", encoding="utf-8"
        )
        (root / "README.md").write_text("fixture\n", encoding="utf-8")
        xcodegen = root / "fake-xcodegen"
        write_executable(
            xcodegen,
            """#!/usr/bin/env python3
import os
import pathlib
import sys

if os.environ.get('FAKE_CONCURRENT') == '1':
    pathlib.Path('README.md').write_text('concurrent edit\\n', encoding='utf-8')
pathlib.Path(os.environ['FAKE_XCODEGEN_LOG']).write_text('xcodegen\\n', encoding='utf-8')
""",
        )
        xcodebuild = root / "fake-xcodebuild"
        write_executable(
            xcodebuild,
            """#!/usr/bin/env python3
import os
import pathlib
import sys

args = sys.argv[1:]
if 'archive' in args:
    stage = 'archive'
    output_flag = '-archivePath'
elif '-exportArchive' in args:
    stage = os.environ.get('FAKE_EXPORT_STAGE', 'export')
    output_flag = '-exportPath'
else:
    stage = 'other'
    output_flag = None
if output_flag and output_flag in args:
    pathlib.Path(args[args.index(output_flag) + 1]).mkdir(parents=True, exist_ok=True)
if os.environ.get('FAKE_FAIL_STAGE') == stage:
    raise SystemExit(17)
""",
        )
        gate = root / "fake-gate"
        write_executable(
            gate,
            """#!/usr/bin/env python3
import os
import pathlib
pathlib.Path(os.environ['FAKE_GATE_LOG']).write_text('gate\\n', encoding='utf-8')
""",
        )
        return script, xcodegen, xcodebuild, gate

    def run_fixture(
        *,
        failure_stage: str | None = None,
        dirty: bool = False,
        concurrent: bool = False,
        self_test_mode: bool = True,
    ) -> tuple[int, pathlib.Path, str, dict[str, str]]:
        directory = pathlib.Path(tempfile.mkdtemp(prefix="uFast-upload-case-"))
        script, xcodegen, xcodebuild, gate = create_fixture(directory)
        subprocess.run(["git", "init", "-q"], cwd=directory, check=True)
        subprocess.run(["git", "config", "user.email", "fixture@example.invalid"], cwd=directory, check=True)
        subprocess.run(["git", "config", "user.name", "Fixture"], cwd=directory, check=True)
        subprocess.run(["git", "add", "."], cwd=directory, check=True)
        subprocess.run(["git", "commit", "-qm", "fixture"], cwd=directory, check=True)
        if dirty:
            (directory / "README.md").write_text("dirty before upload\n", encoding="utf-8")
        gate_log = directory.parent / f"{directory.name}-gate.log"
        xcodegen_log = directory.parent / f"{directory.name}-xcodegen.log"
        archive_root = directory.parent / f"{directory.name}-archives"
        environment = os.environ.copy()
        environment.update(
            {
                "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer",
                "XCODEGEN_BIN": str(xcodegen),
                "XCODEBUILD_BIN": str(xcodebuild),
                "TESTFLIGHT_GATE_BIN": str(gate),
                "TESTFLIGHT_SELF_TEST_MODE": "1" if self_test_mode else "0",
                "TESTFLIGHT_ARCHIVE_ROOT": str(archive_root),
                "FAKE_GATE_LOG": str(gate_log),
                "FAKE_XCODEGEN_LOG": str(xcodegen_log),
                "FAKE_FAIL_STAGE": failure_stage or "",
                "FAKE_EXPORT_STAGE": failure_stage or "export",
                "FAKE_CONCURRENT": "1" if concurrent else "0",
            }
        )
        completed = subprocess.run(
            [str(script)], cwd=directory, env=environment, capture_output=True, text=True
        )
        return completed.returncode, directory / "project.yml", completed.stdout + completed.stderr, {
            "gate": str(gate_log),
            "xcodegen": str(xcodegen_log),
        }

    original = b"MARKETING_VERSION: 1.0.0\nCURRENT_PROJECT_VERSION: 10\n"
    for stage in ("archive", "export", "upload"):
        code, project, output, logs = run_fixture(failure_stage=stage)
        if code == 0 or project.read_bytes() != original:
            raise GateError(f"actual upload script did not roll back exact project after {stage} failure: {output}")
        if not pathlib.Path(logs["gate"]).is_file():
            raise GateError(f"authoritative gate boundary was not executed before {stage} failure")

    code, project, output, logs = run_fixture()
    if code != 0 or project.read_bytes() != original.replace(b": 10", b": 11"):
        raise GateError(f"actual upload script did not retain increment on success: {output}")
    if not pathlib.Path(logs["gate"]).is_file():
        raise GateError("authoritative gate boundary was not executed on successful upload")

    code, project, output, logs = run_fixture(dirty=True)
    if code == 0 or project.read_bytes() != original or pathlib.Path(logs["gate"]).exists():
        raise GateError(f"dirty upload fixture was not refused before gate execution: {output}")

    code, project, output, logs = run_fixture(self_test_mode=False)
    if code == 0 or project.read_bytes() != original or pathlib.Path(logs["gate"]).exists():
        raise GateError(f"fake gate seam escaped explicit self-test mode: {output}")

    code, project, output, _ = run_fixture(concurrent=True)
    concurrent_project = b"MARKETING_VERSION: 1.0.0\nCURRENT_PROJECT_VERSION: 11\n"
    if code == 0 or project.read_bytes() != concurrent_project:
        raise GateError(f"concurrent edit was overwritten or accepted: {output}")
    print(
        "Upload transaction self-test passed: actual script archive/export/upload rollback, "
        "success retention, dirty refusal, and concurrent-edit guard"
    )


def self_test() -> None:
    # The entitlement module owns its parser and its source/built allowlist.
    completed = subprocess.run(
        [sys.executable, str(ROOT / "scripts/verify_entitlements.py"), "--self-test"],
        cwd=ROOT,
        check=False,
    )
    if completed.returncode != 0:
        raise GateError("entitlement negative-control self-test failed")
    entitlement_resolver_self_test()
    unit_count_parser_self_test()
    with tempfile.TemporaryDirectory(prefix="uFast-release-gate-") as directory:
        root = pathlib.Path(directory)
        privacy = root / "PrivacyInfo.xcprivacy"
        with privacy.open("wb") as handle:
            plistlib.dump({"NSPrivacyAccessedAPITypes": []}, handle)
        validate_privacy_fixture(privacy)
        positive = positive_manifest_fixture(root)
        assert_manifest_valid(positive)
        manifest_path = root / "release-manifest.json"
        for name in ("version", "privacy", "ui"):
            assert_gate_failure_without_manifest(
                manifest_path,
                f"injected {name} orchestration failure",
                lambda name=name: run_gate(
                    root / "missing.xcresult", manifest_path, injected_failure=name
                ),
            )
        assert_gate_failure_without_manifest(
            manifest_path,
            "version mismatch",
            lambda: validate_version_fixture({"app": "1.0.0", "widget": "1.0.1"}),
        )
        assert_gate_failure_without_manifest(
            manifest_path,
            "missing privacy declaration",
            lambda: validate_privacy_fixture(root / "missing.xcprivacy"),
        )
        assert_gate_failure_without_manifest(
            manifest_path,
            "stale or unbound UI evidence",
            lambda: validate_ui_binding(root / "missing.xcresult", "sha256:fixture"),
        )
        assert_gate_failure_without_manifest(
            manifest_path,
            "failed underlying command",
            lambda: assert_manifest_valid(
                {
                    **positive,
                    "commands": [{"name": "failed-child", "exit_code": 7}],
                }
            ),
        )
        command_results: list[CommandResult] = []
        assert_gate_failure_without_manifest(
            manifest_path,
            "failed child command",
            lambda: run_command(
                "failed-child",
                [sys.executable, "-c", "raise SystemExit(7)"],
                root / "failed-child-logs",
                command_results,
            ),
        )
        if not command_results or command_results[-1].exit_code != 7:
            raise GateError("failed child command did not propagate its exit code")
    upload_transaction_self_test()
    print(
        "Release gate self-test passed: complete positive manifest plus gate-level "
        "missing/forbidden entitlement, version/privacy/UI, and failed-child controls"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ui-result", type=pathlib.Path, default=None)
    parser.add_argument("--manifest", type=pathlib.Path, default=MANIFEST_DEFAULT)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--upload-self-test", action="store_true")
    parser.add_argument("--print-source-freeze-id", action="store_true")
    parser.add_argument("--write-ui-binding", type=pathlib.Path)
    parser.add_argument("--source-freeze-label", default="unspecified")
    parser.add_argument("--content-source-freeze-id")
    parser.add_argument("--worker-count", type=int, default=4)
    arguments = parser.parse_args()

    try:
        if arguments.print_source_freeze_id:
            print(content_source_freeze_id())
            return 0
        if arguments.write_ui_binding:
            write_ui_binding(
                arguments.write_ui_binding,
                label=arguments.source_freeze_label,
                worker_count=arguments.worker_count,
                captured_id=arguments.content_source_freeze_id,
            )
            return 0
        if arguments.self_test or arguments.upload_self_test:
            self_test()
            return 0
        ui_result = arguments.ui_result or (
            pathlib.Path(os.environ["UI_XCRESULT"])
            if os.environ.get("UI_XCRESULT")
            else (
                pathlib.Path(os.environ["RELEASE_GATE_UI_XCRESULT"])
                if os.environ.get("RELEASE_GATE_UI_XCRESULT")
                else None
            )
        )
        if ui_result is None:
            raise GateError("UI_XCRESULT is required; release evidence must be source-bound")
        return run_gate(ui_result, arguments.manifest)
    except (GateError, OSError, subprocess.CalledProcessError) as error:
        print(f"release gate failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
