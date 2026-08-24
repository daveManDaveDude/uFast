#!/usr/bin/env python3
"""Enforce uFast's tracked binary and generated-evidence retention policy.

The normal invocation inspects the current working tree.  ``--base`` compares
the named commit to ``HEAD`` using exactly that commit as the range base; it
does not inspect remotes or infer a merge base.  ``--write-baseline`` is the
one-time, explicit command used to freeze the historical manifest.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from typing import Any, Iterable


ROOT = pathlib.Path(__file__).resolve().parents[1]
BASELINE_PATH = ROOT / "docs/TRACKED_BINARY_BASELINE.json"
ALLOWLIST_PATH = ROOT / "docs/TRACKED_BINARY_ALLOWLIST.json"
BASELINE_COMMIT = "7c45dbfaca644845645bb3f76811ebb62cdf1876"
SCHEMA_VERSION = 1
MINIMUM_BYTES = 1_048_576
GENERATED_DIRECTORIES = (
    "artifacts/",
    ".testflight-archives/",
    ".derived-data/",
)
GENERATED_EXTENSIONS = (
    ".xcresult",
    ".xcarchive",
    ".trace",
    ".mp4",
    ".mov",
    ".zip",
    ".log",
)
OWNER_CATEGORIES = frozenset({"app-resource", "design-golden", "release-evidence"})
WILDCARD_CHARACTERS = frozenset("*?[]")
GENERIC_PURPOSES = frozenset(
    {"misc", "temporary", "temp", "tbd", "todo", "none", "placeholder", "test"}
)


class BinaryEvidenceError(RuntimeError):
    """A binary-evidence policy or manifest violation."""


@dataclass(frozen=True)
class FileRecord:
    path: str
    bytes: int
    sha256: str

    def as_dict(self) -> dict[str, Any]:
        return {"path": self.path, "bytes": self.bytes, "sha256": self.sha256}


@dataclass(frozen=True)
class AllowlistEntry:
    path: str
    sha256: str
    max_bytes: int
    purpose: str
    owner_category: str
    review_note: str


@dataclass(frozen=True)
class CheckSummary:
    mode: str
    baseline_entries: int
    changed_or_added: int
    grandfathered: int
    allowlisted: int


def _run_git(root: pathlib.Path, arguments: list[str], *, check: bool = True) -> bytes:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        detail = completed.stderr.decode("utf-8", errors="replace").strip()
        raise BinaryEvidenceError(
            f"git {' '.join(arguments)} failed with exit {completed.returncode}: {detail}"
        )
    return completed.stdout


def _commit_sha(root: pathlib.Path, revision: str) -> str:
    resolved = _run_git(root, ["rev-parse", "--verify", f"{revision}^{{commit}}"])
    return resolved.decode("ascii").strip()


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _is_text(data: bytes) -> bool:
    """Use a deterministic, dependency-free text/binary classification."""

    if b"\0" in data:
        return False
    try:
        decoded = data.decode("utf-8")
    except UnicodeDecodeError:
        return False
    sample = decoded[:8192]
    if not sample:
        return True
    control_count = sum(
        1
        for character in sample
        if ord(character) < 32 and character not in {"\n", "\r", "\t", "\f", "\b"}
    )
    return control_count <= max(1, len(sample) // 100)


def is_generated_evidence(path: str) -> bool:
    normalized = path.replace("\\", "/")
    if any(
        normalized == directory[:-1] or normalized.startswith(directory)
        for directory in GENERATED_DIRECTORIES
    ):
        return True
    components = normalized.split("/")
    return any(
        component.lower().endswith(extension)
        for component in components
        for extension in GENERATED_EXTENSIONS
    )


def _validate_relative_path(path: Any, *, label: str) -> str:
    if not isinstance(path, str) or not path:
        raise BinaryEvidenceError(f"{label} path must be a non-empty string")
    if "\\" in path or any(character in path for character in WILDCARD_CHARACTERS):
        raise BinaryEvidenceError(f"{label} path must be exact and wildcard-free: {path!r}")
    candidate = pathlib.PurePosixPath(path)
    if candidate.is_absolute() or ".." in candidate.parts or "." in candidate.parts:
        raise BinaryEvidenceError(f"{label} path must be repository-relative: {path!r}")
    if candidate.as_posix() != path:
        raise BinaryEvidenceError(f"{label} path is not normalized: {path!r}")
    return path


def _validate_sha(value: Any, *, label: str) -> str:
    if not isinstance(value, str) or len(value) != 64 or any(
        character not in "0123456789abcdef" for character in value
    ):
        raise BinaryEvidenceError(f"{label} must be a lowercase SHA-256 digest")
    return value


def _validate_manifest_shape(payload: Any, *, kind: str) -> None:
    if not isinstance(payload, dict) or payload.get("schema_version") != SCHEMA_VERSION:
        raise BinaryEvidenceError(f"{kind} manifest has unsupported schema_version")
    if kind == "baseline":
        required = {"schema_version", "source_commit", "minimum_bytes", "files"}
        if set(payload) != required:
            raise BinaryEvidenceError(
                f"baseline manifest keys must be exactly {sorted(required)}"
            )
        if payload["source_commit"] != BASELINE_COMMIT:
            raise BinaryEvidenceError(
                "baseline manifest must be frozen from commit " + BASELINE_COMMIT
            )
        if payload["minimum_bytes"] != MINIMUM_BYTES:
            raise BinaryEvidenceError("baseline manifest has the wrong byte threshold")
        if not isinstance(payload["files"], list):
            raise BinaryEvidenceError("baseline manifest files must be an array")
    else:
        required = {"schema_version", "entries"}
        if set(payload) != required:
            raise BinaryEvidenceError(
                f"allowlist manifest keys must be exactly {sorted(required)}"
            )
        if not isinstance(payload["entries"], list):
            raise BinaryEvidenceError("allowlist entries must be an array")


def load_baseline(path: pathlib.Path = BASELINE_PATH) -> dict[str, FileRecord]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise BinaryEvidenceError(f"could not read baseline manifest {path}: {error}") from error
    _validate_manifest_shape(payload, kind="baseline")
    records: dict[str, FileRecord] = {}
    previous = ""
    for index, raw in enumerate(payload["files"]):
        if not isinstance(raw, dict) or set(raw) != {"path", "bytes", "sha256"}:
            raise BinaryEvidenceError(f"baseline file entry {index} has the wrong shape")
        relative = _validate_relative_path(raw["path"], label=f"baseline file {index}")
        if relative <= previous:
            raise BinaryEvidenceError("baseline files must be unique and sorted by path")
        previous = relative
        byte_count = raw["bytes"]
        if not isinstance(byte_count, int) or isinstance(byte_count, bool) or byte_count < 0:
            raise BinaryEvidenceError(f"baseline file {relative} has invalid bytes")
        digest = _validate_sha(raw["sha256"], label=f"baseline file {relative}")
        records[relative] = FileRecord(relative, byte_count, digest)
    return records


def load_allowlist(path: pathlib.Path = ALLOWLIST_PATH) -> dict[str, AllowlistEntry]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise BinaryEvidenceError(f"could not read allowlist manifest {path}: {error}") from error
    _validate_manifest_shape(payload, kind="allowlist")
    entries: dict[str, AllowlistEntry] = {}
    for index, raw in enumerate(payload["entries"]):
        required = {"path", "sha256", "max_bytes", "purpose", "owner_category", "review_note"}
        if not isinstance(raw, dict) or set(raw) != required:
            raise BinaryEvidenceError(f"allowlist entry {index} has the wrong shape")
        relative = _validate_relative_path(raw["path"], label=f"allowlist entry {index}")
        if relative in entries:
            raise BinaryEvidenceError(f"allowlist path is duplicated: {relative}")
        digest = _validate_sha(raw["sha256"], label=f"allowlist entry {relative}")
        max_bytes = raw["max_bytes"]
        if not isinstance(max_bytes, int) or isinstance(max_bytes, bool) or max_bytes < 0:
            raise BinaryEvidenceError(f"allowlist entry {relative} has invalid max_bytes")
        purpose = raw["purpose"]
        if not isinstance(purpose, str) or not purpose.strip():
            raise BinaryEvidenceError(f"allowlist entry {relative} needs a specific purpose")
        if purpose.strip().lower() in GENERIC_PURPOSES or len(purpose.strip()) < 12:
            raise BinaryEvidenceError(f"allowlist entry {relative} has a generic purpose")
        owner_category = raw["owner_category"]
        if owner_category not in OWNER_CATEGORIES:
            raise BinaryEvidenceError(
                f"allowlist entry {relative} has invalid owner_category: {owner_category!r}"
            )
        review_note = raw["review_note"]
        if not isinstance(review_note, str) or not review_note.strip():
            raise BinaryEvidenceError(f"allowlist entry {relative} needs a review note")
        entries[relative] = AllowlistEntry(
            relative, digest, max_bytes, purpose.strip(), owner_category, review_note.strip()
        )
    return entries


def _parse_tree(root: pathlib.Path, revision: str) -> list[tuple[str, int, str]]:
    output = _run_git(root, ["ls-tree", "-r", "--long", "-z", revision])
    trees: list[tuple[str, int, str]] = []
    for item in output.split(b"\0"):
        if not item:
            continue
        header, raw_path = item.split(b"\t", 1)
        fields = header.decode("ascii").split()
        if len(fields) != 4 or fields[1] != "blob":
            continue
        trees.append((raw_path.decode("utf-8"), int(fields[3]), fields[2]))
    return trees


def _git_blob(root: pathlib.Path, revision: str, path: str) -> bytes:
    return _run_git(root, ["show", f"{revision}:{path}"])


def baseline_records_from_commit(
    root: pathlib.Path = ROOT, revision: str = BASELINE_COMMIT
) -> list[FileRecord]:
    resolved = _commit_sha(root, revision)
    records: list[FileRecord] = []
    for path, tree_size, _object_id in _parse_tree(root, resolved):
        data = _git_blob(root, resolved, path)
        if tree_size != len(data):
            raise BinaryEvidenceError(f"Git tree size mismatch for {path}")
        if is_generated_evidence(path) or (
            len(data) >= MINIMUM_BYTES and not _is_text(data)
        ):
            records.append(FileRecord(path, len(data), _sha256(data)))
    return sorted(records, key=lambda record: record.path)


def verify_baseline_against_commit(
    root: pathlib.Path, records: dict[str, FileRecord], revision: str = BASELINE_COMMIT
) -> None:
    resolved = _commit_sha(root, revision)
    expected = {
        record.path: record
        for record in baseline_records_from_commit(root, resolved)
    }
    actual_paths = set(records)
    expected_paths = set(expected)
    missing = sorted(expected_paths - actual_paths)
    unexpected = sorted(actual_paths - expected_paths)
    if missing or unexpected:
        details: list[str] = []
        if missing:
            details.append(f"missing paths: {', '.join(missing)}")
        if unexpected:
            details.append(f"unexpected paths: {', '.join(unexpected)}")
        raise BinaryEvidenceError(
            "baseline record set does not match frozen commit ("
            + "; ".join(details)
            + ")"
        )
    for path in sorted(expected_paths):
        record = records[path]
        historical = expected[path]
        if record.bytes != historical.bytes or record.sha256 != historical.sha256:
            raise BinaryEvidenceError(
                f"baseline does not reproduce {path} from {resolved}"
            )


def _git_paths(root: pathlib.Path, arguments: list[str]) -> set[str]:
    output = _run_git(root, arguments)
    return {item.decode("utf-8") for item in output.split(b"\0") if item}


def _working_tree_paths(root: pathlib.Path) -> list[str]:
    visible = _git_paths(
        root, ["ls-files", "--cached", "--others", "--exclude-standard", "-z"]
    )
    ignored = _git_paths(
        root, ["ls-files", "--others", "--ignored", "--exclude-standard", "-z"]
    )
    return sorted(visible | ignored)


def _working_tree_inventory(
    root: pathlib.Path,
    *,
    baseline: dict[str, FileRecord],
    allowlist: dict[str, AllowlistEntry],
) -> tuple[dict[str, FileRecord], set[str]]:
    visible = _git_paths(
        root, ["ls-files", "--cached", "--others", "--exclude-standard", "-z"]
    )
    ignored = _git_paths(
        root, ["ls-files", "--others", "--ignored", "--exclude-standard", "-z"]
    )
    listed_paths = visible | ignored
    available_paths = {
        path for path in listed_paths if (root / path).is_file()
    }
    records: dict[str, FileRecord] = {}
    for path in sorted(available_paths):
        absolute = root / path
        size = absolute.stat().st_size
        generated = is_generated_evidence(path)
        requires_review = generated or size >= MINIMUM_BYTES
        if path in ignored and requires_review and path not in baseline and path not in allowlist:
            reason = "generated evidence" if generated else "file at least 1 MiB"
            raise BinaryEvidenceError(
                f"unapproved ignored {reason}: {path} ({size} bytes)"
            )
        if not requires_review and path not in baseline and path not in allowlist:
            continue
        data = absolute.read_bytes()
        records[path] = FileRecord(path, len(data), _sha256(data))
    return records, available_paths


def _commit_change_paths(root: pathlib.Path, base: str) -> list[str]:
    _commit_sha(root, base)
    output = _run_git(root, ["diff", "--name-status", "--no-renames", "-z", base, "HEAD"])
    parts = output.split(b"\0")
    paths: set[str] = set()
    for index in range(0, len(parts) - 1, 2):
        status = parts[index].decode("ascii")
        path = parts[index + 1].decode("utf-8")
        if status and status[0] != "D":
            paths.add(path)
    return sorted(paths)


def _commit_records(
    root: pathlib.Path, paths: Iterable[str]
) -> tuple[dict[str, FileRecord], set[str]]:
    target_paths = {path for path, _size, _object_id in _parse_tree(root, "HEAD")}
    records: dict[str, FileRecord] = {}
    for path in sorted(set(paths)):
        if path not in target_paths:
            continue
        data = _git_blob(root, "HEAD", path)
        records[path] = FileRecord(path, len(data), _sha256(data))
    return records, target_paths


def _evaluate(
    *,
    baseline: dict[str, FileRecord],
    allowlist: dict[str, AllowlistEntry],
    current: dict[str, FileRecord],
    available_paths: set[str],
    mode: str,
    changed_paths: Iterable[str] | None = None,
) -> CheckSummary:
    violations: list[str] = []
    missing = sorted(path for path in baseline if path not in available_paths)
    violations.extend(f"baseline file is missing: {path}" for path in missing)

    candidates = (
        sorted(changed_paths)
        if changed_paths is not None
        else sorted(current)
    )
    changed_or_added = 0
    grandfathered = 0
    allowlisted = 0
    for path in candidates:
        record = current.get(path)
        if record is None:
            continue
        historical = baseline.get(path)
        if historical is not None and historical.sha256 == record.sha256:
            grandfathered += 1
            continue
        generated = is_generated_evidence(path)
        requires_review = generated or record.bytes >= MINIMUM_BYTES
        if not requires_review:
            continue
        changed_or_added += 1
        entry = allowlist.get(path)
        if entry is None:
            reason = "generated evidence" if generated else "file at least 1 MiB"
            violations.append(f"unapproved {reason}: {path} ({record.bytes} bytes)")
            continue
        if entry.sha256 != record.sha256:
            violations.append(f"allowlist SHA-256 mismatch: {path}")
            continue
        if record.bytes > entry.max_bytes:
            violations.append(
                f"allowlist maximum exceeded: {path} ({record.bytes} > {entry.max_bytes})"
            )
            continue
        allowlisted += 1

    if violations:
        raise BinaryEvidenceError("; ".join(violations))
    return CheckSummary(mode, len(baseline), changed_or_added, grandfathered, allowlisted)


def check(
    root: pathlib.Path = ROOT,
    *,
    baseline_path: pathlib.Path = BASELINE_PATH,
    allowlist_path: pathlib.Path = ALLOWLIST_PATH,
    base: str | None = None,
    verify_source: bool = True,
) -> CheckSummary:
    baseline = load_baseline(baseline_path)
    allowlist = load_allowlist(allowlist_path)
    if verify_source:
        verify_baseline_against_commit(root, baseline, BASELINE_COMMIT)
    if base is None:
        current, available_paths = _working_tree_inventory(
            root, baseline=baseline, allowlist=allowlist
        )
        return _evaluate(
            baseline=baseline,
            allowlist=allowlist,
            current=current,
            available_paths=available_paths,
            mode="working-tree",
        )
    changed = _commit_change_paths(root, base)
    current_paths = sorted(set(changed) | set(baseline))
    current, target_paths = _commit_records(root, current_paths)
    return _evaluate(
        baseline=baseline,
        allowlist=allowlist,
        current=current,
        available_paths=target_paths,
        mode=f"explicit-base:{_commit_sha(root, base)}..HEAD",
        changed_paths=current_paths,
    )


def write_baseline(
    root: pathlib.Path = ROOT,
    *,
    output: pathlib.Path = BASELINE_PATH,
    revision: str = BASELINE_COMMIT,
    force: bool = False,
) -> int:
    if output.exists() and not force:
        raise BinaryEvidenceError(f"refusing to overwrite existing baseline: {output}")
    resolved = _commit_sha(root, revision)
    if resolved != BASELINE_COMMIT:
        raise BinaryEvidenceError(
            f"baseline source must resolve to {BASELINE_COMMIT}, got {resolved}"
        )
    records = baseline_records_from_commit(root, resolved)
    payload = {
        "schema_version": SCHEMA_VERSION,
        "source_commit": BASELINE_COMMIT,
        "minimum_bytes": MINIMUM_BYTES,
        "files": [record.as_dict() for record in records],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote baseline: {output} ({len(records)} files from {BASELINE_COMMIT})")
    return len(records)


def _expect_failure(label: str, action) -> None:
    try:
        action()
    except BinaryEvidenceError:
        print(f"negative control passed: {label}")
    else:
        raise BinaryEvidenceError(f"negative control unexpectedly passed: {label}")


def _fixture_manifests(root: pathlib.Path, records: list[FileRecord], entries: list[dict[str, Any]]) -> tuple[pathlib.Path, pathlib.Path]:
    baseline = root / "baseline.json"
    allowlist = root / "allowlist.json"
    baseline.write_text(
        json.dumps(
            {
                "schema_version": SCHEMA_VERSION,
                "source_commit": BASELINE_COMMIT,
                "minimum_bytes": MINIMUM_BYTES,
                "files": [record.as_dict() for record in sorted(records, key=lambda item: item.path)],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    allowlist.write_text(
        json.dumps({"schema_version": SCHEMA_VERSION, "entries": entries}, indent=2) + "\n",
        encoding="utf-8",
    )
    return baseline, allowlist


def self_test() -> None:
    """Exercise all story-specified negative and allowlist fixture classes."""

    baseline_records = baseline_records_from_commit()
    if len(baseline_records) != 58:
        raise BinaryEvidenceError(
            f"historical baseline count changed unexpectedly: {len(baseline_records)}"
        )
    with tempfile.TemporaryDirectory(prefix="ufast-binary-baseline-setup-") as temporary:
        manifest_root = pathlib.Path(temporary)
        wrong_path_records = list(baseline_records)
        wrong_path_records[-1] = FileRecord(
            "README.md",
            wrong_path_records[-1].bytes,
            wrong_path_records[-1].sha256,
        )
        wrong_path, wrong_allowlist = _fixture_manifests(
            manifest_root, wrong_path_records, []
        )
        _expect_failure(
            "baseline wrong path set",
            lambda: check(
                ROOT,
                baseline_path=wrong_path,
                allowlist_path=wrong_allowlist,
            ),
        )
        short_path, short_allowlist = _fixture_manifests(
            manifest_root, baseline_records[:-1], []
        )
        _expect_failure(
            "baseline wrong count",
            lambda: check(
                ROOT,
                baseline_path=short_path,
                allowlist_path=short_allowlist,
            ),
        )
    with tempfile.TemporaryDirectory(prefix="ufast-binary-deletion-") as temporary:
        root = pathlib.Path(temporary)
        _run_git(root, ["init", "-q"])
        _run_git(root, ["config", "user.email", "binary-evidence@example.invalid"])
        _run_git(root, ["config", "user.name", "Binary Evidence Deletion Self-Test"])
        shutil.copy2(ROOT / ".gitignore", root / ".gitignore")
        evidence = root / "docs/existing-evidence.log"
        evidence.parent.mkdir(parents=True)
        evidence.write_bytes(b"original evidence")
        _run_git(root, ["add", "-f", "docs/existing-evidence.log"])
        _run_git(root, ["commit", "-qm", "baseline deletion fixture"])
        base = _commit_sha(root, "HEAD")
        original = FileRecord(
            "docs/existing-evidence.log",
            evidence.stat().st_size,
            _sha256(evidence.read_bytes()),
        )
        baseline_path, allowlist_path = _fixture_manifests(root, [original], [])
        evidence.unlink()
        _expect_failure(
            "deleted baseline working-tree file",
            lambda: check(
                root,
                baseline_path=baseline_path,
                allowlist_path=allowlist_path,
                verify_source=False,
            ),
        )
        _run_git(root, ["add", "-u", "docs/existing-evidence.log"])
        _run_git(root, ["commit", "-qm", "delete baseline fixture"])
        _expect_failure(
            "deleted baseline explicit-base file",
            lambda: check(
                root,
                baseline_path=baseline_path,
                allowlist_path=allowlist_path,
                base=base,
                verify_source=False,
            ),
        )
    with tempfile.TemporaryDirectory(prefix="ufast-binary-evidence-") as temporary:
        root = pathlib.Path(temporary)
        _run_git(root, ["init", "-q"])
        _run_git(root, ["config", "user.email", "binary-evidence@example.invalid"])
        _run_git(root, ["config", "user.name", "Binary Evidence Self-Test"])
        # Use the repository's actual ignore rules so ignored evidence cannot
        # silently escape the working-tree inventory. The temporary Git
        # repository and all of its fixtures are removed after this test.
        shutil.copy2(ROOT / ".gitignore", root / ".gitignore")
        log = root / "capture.log"
        log.write_text("small generated log\n", encoding="utf-8")
        large_binary = root / "large-random-binary"
        large_binary.write_bytes(bytes(range(256)) * ((MINIMUM_BYTES // 256) + 1))
        app_asset = root / "uFast/Resources/Assets.xcassets/Fixture.imageset/Fixture.png"
        app_asset.parent.mkdir(parents=True)
        app_asset.write_bytes(b"asset" * 100)
        grandfathered = root / "docs/existing-evidence.log"
        grandfathered.parent.mkdir(parents=True)
        grandfathered.write_bytes(b"original evidence")
        _run_git(root, ["add", "-f", "docs/existing-evidence.log"])
        _run_git(root, ["commit", "-qm", "baseline fixture"])
        original = FileRecord("docs/existing-evidence.log", grandfathered.stat().st_size, _sha256(grandfathered.read_bytes()))
        baseline_path, allowlist_path = _fixture_manifests(root, [original], [])

        _expect_failure(
            "ignored small generated log",
            lambda: check(root, baseline_path=baseline_path, allowlist_path=allowlist_path, verify_source=False),
        )
        log.unlink()
        ignored_artifact = root / "artifacts/small.txt"
        ignored_artifact.parent.mkdir(parents=True)
        ignored_artifact.write_text("small artifact\n", encoding="utf-8")
        _expect_failure(
            "ignored small generated artifact",
            lambda: check(root, baseline_path=baseline_path, allowlist_path=allowlist_path, verify_source=False),
        )
        ignored_artifact.unlink()
        _expect_failure(
            "large random binary",
            lambda: check(root, baseline_path=baseline_path, allowlist_path=allowlist_path, verify_source=False),
        )
        large_binary.unlink()
        grandfathered.write_bytes(b"changed evidence")
        _expect_failure(
            "changed grandfathered file",
            lambda: check(root, baseline_path=baseline_path, allowlist_path=allowlist_path, verify_source=False),
        )
        grandfathered.write_bytes(b"original evidence")
        summary = check(root, baseline_path=baseline_path, allowlist_path=allowlist_path, verify_source=False)
        if summary.grandfathered != 1:
            raise BinaryEvidenceError("grandfathered fixture was not preserved")
        small_summary = check(root, baseline_path=baseline_path, allowlist_path=allowlist_path, verify_source=False)
        if small_summary.changed_or_added != 0:
            raise BinaryEvidenceError("sub-1MiB app asset was incorrectly classified")

        large_asset = root / "uFast/Resources/Assets.xcassets/Large.imageset/Large.png"
        large_asset.parent.mkdir(parents=True)
        large_asset.write_bytes(b"large app resource" * ((MINIMUM_BYTES // 18) + 1))
        large_record = FileRecord("uFast/Resources/Assets.xcassets/Large.imageset/Large.png", large_asset.stat().st_size, _sha256(large_asset.read_bytes()))
        entry = {
            "path": large_record.path,
            "sha256": large_record.sha256,
            "max_bytes": large_record.bytes,
            "purpose": "Reviewed long-term app resource",
            "owner_category": "app-resource",
            "review_note": "Product resource has an explicit retention purpose.",
        }
        allowlisted_baseline, allowlisted_manifest = _fixture_manifests(root, [original], [entry])
        allowlisted_summary = check(root, baseline_path=allowlisted_baseline, allowlist_path=allowlisted_manifest, verify_source=False)
        if allowlisted_summary.allowlisted != 1:
            raise BinaryEvidenceError("allowlisted large app asset was not accepted")
        oversized_baseline, oversized_manifest = _fixture_manifests(
            root,
            [original],
            [{**entry, "max_bytes": large_record.bytes - 1}],
        )
        _expect_failure(
            "oversized allowlist replacement",
            lambda: check(
                root,
                baseline_path=oversized_baseline,
                allowlist_path=oversized_manifest,
                verify_source=False,
            ),
        )
        _expect_failure(
            "wildcard allowlist path",
            lambda: _fixture_manifests(
                root,
                [original],
                [{**entry, "path": "uFast/**/*.png"}],
            )
            and load_allowlist(root / "allowlist.json"),
        )
    print("tracked binary evidence checker self-test passed: baseline, working-tree fixtures, allowlist rules")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--base", help="explicit commit used as the base for base..HEAD evaluation")
    parser.add_argument("--write-baseline", action="store_true")
    parser.add_argument("--force", action="store_true", help="allow --write-baseline to replace an existing manifest")
    arguments = parser.parse_args()
    try:
        if arguments.self_test:
            self_test()
        elif arguments.write_baseline:
            if arguments.base:
                raise BinaryEvidenceError("--write-baseline cannot be combined with --base")
            write_baseline(force=arguments.force)
        else:
            summary = check(base=arguments.base)
            print(
                "tracked binary evidence check passed: "
                f"{summary.mode}; {summary.baseline_entries} baseline files, "
                f"{summary.changed_or_added} changed/new reviewed, "
                f"{summary.grandfathered} grandfathered, {summary.allowlisted} allowlisted"
            )
    except (BinaryEvidenceError, OSError, ValueError) as error:
        print(f"tracked binary evidence check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
