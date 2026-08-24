from __future__ import annotations

import importlib.util
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECKER_PATH = ROOT / "scripts/check_tracked_binary_evidence.py"
SPEC = importlib.util.spec_from_file_location("check_tracked_binary_evidence", CHECKER_PATH)
CHECKER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = CHECKER
SPEC.loader.exec_module(CHECKER)


class CheckTrackedBinaryEvidenceTests(unittest.TestCase):
    def test_historical_baseline_is_reproducible(self):
        records = CHECKER.load_baseline()
        self.assertEqual(len(records), 58)
        CHECKER.verify_baseline_against_commit(ROOT, records)

    def test_baseline_rejects_wrong_path_set_and_count(self):
        records = list(CHECKER.load_baseline().values())
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            wrong_path_records = list(records)
            wrong_path_records[-1] = CHECKER.FileRecord(
                "README.md",
                wrong_path_records[-1].bytes,
                wrong_path_records[-1].sha256,
            )
            for fixture_records in (wrong_path_records, records[:-1]):
                baseline, allowlist = self._manifests(root, records=fixture_records)
                with self.assertRaises(CHECKER.BinaryEvidenceError):
                    CHECKER.check(
                        ROOT,
                        baseline_path=baseline,
                        allowlist_path=allowlist,
                    )

    def test_working_tree_rejects_ignored_generated_evidence_under_real_rules(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            self._init_git(root)
            shutil.copy2(ROOT / ".gitignore", root / ".gitignore")
            baseline, allowlist = self._manifests(root)
            for path in (root / "capture.log", root / "artifacts/small.txt"):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("ignored fixture\n", encoding="utf-8")
                with self.assertRaises(CHECKER.BinaryEvidenceError):
                    CHECKER.check(
                        root,
                        baseline_path=baseline,
                        allowlist_path=allowlist,
                        verify_source=False,
                    )
                path.unlink()

    def test_explicit_base_rechecks_baseline_changed_before_selected_base(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            self._init_git(root)
            shutil.copy2(ROOT / ".gitignore", root / ".gitignore")
            (root / "README.md").write_text("base\n", encoding="utf-8")
            self._git(root, "add", "README.md")
            self._git(root, "commit", "-qm", "base")
            evidence = root / "docs/existing-evidence.log"
            evidence.parent.mkdir(parents=True)
            evidence.write_bytes(b"original evidence")
            self._git(root, "add", "-f", "docs/existing-evidence.log")
            self._git(root, "commit", "-qm", "baseline evidence")
            original = CHECKER.FileRecord(
                "docs/existing-evidence.log",
                evidence.stat().st_size,
                CHECKER._sha256(evidence.read_bytes()),
            )
            evidence.write_bytes(b"changed before selected base")
            self._git(root, "add", "-f", "docs/existing-evidence.log")
            self._git(root, "commit", "-qm", "pre-base evidence change")
            base = self._git(root, "rev-parse", "HEAD").strip()
            (root / "README.md").write_text("head\n", encoding="utf-8")
            self._git(root, "add", "README.md")
            self._git(root, "commit", "-qm", "unrelated head change")
            baseline, allowlist = self._manifests(root, records=[original])
            with self.assertRaises(CHECKER.BinaryEvidenceError):
                CHECKER.check(
                    root,
                    baseline_path=baseline,
                    allowlist_path=allowlist,
                    base=base,
                    verify_source=False,
                )

    def test_deleted_baseline_file_is_rejected_in_both_modes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            self._init_git(root)
            shutil.copy2(ROOT / ".gitignore", root / ".gitignore")
            evidence = root / "docs/existing-evidence.log"
            evidence.parent.mkdir(parents=True)
            evidence.write_bytes(b"original evidence")
            self._git(root, "add", "-f", "docs/existing-evidence.log")
            self._git(root, "commit", "-qm", "baseline deletion fixture")
            base = self._git(root, "rev-parse", "HEAD").strip()
            original = CHECKER.FileRecord(
                "docs/existing-evidence.log",
                evidence.stat().st_size,
                CHECKER._sha256(evidence.read_bytes()),
            )
            baseline, allowlist = self._manifests(root, records=[original])
            evidence.unlink()
            with self.assertRaises(CHECKER.BinaryEvidenceError):
                CHECKER.check(
                    root,
                    baseline_path=baseline,
                    allowlist_path=allowlist,
                    verify_source=False,
                )
            self._git(root, "add", "-u", "docs/existing-evidence.log")
            self._git(root, "commit", "-qm", "delete baseline fixture")
            with self.assertRaises(CHECKER.BinaryEvidenceError):
                CHECKER.check(
                    root,
                    baseline_path=baseline,
                    allowlist_path=allowlist,
                    base=base,
                    verify_source=False,
                )

    def test_allowlist_requires_exact_hash_and_bounded_size(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            self._init_git(root)
            asset = root / "uFast/Resources/Assets.xcassets/Large.imageset/Large.png"
            asset.parent.mkdir(parents=True)
            asset.write_bytes(b"large asset" * ((CHECKER.MINIMUM_BYTES // 11) + 1))
            record = CHECKER.FileRecord(
                "uFast/Resources/Assets.xcassets/Large.imageset/Large.png",
                asset.stat().st_size,
                CHECKER._sha256(asset.read_bytes()),
            )
            baseline, allowlist = self._manifests(
                root,
                entries=[
                    {
                        "path": record.path,
                        "sha256": record.sha256,
                        "max_bytes": record.bytes,
                        "purpose": "Reviewed long-term app resource",
                        "owner_category": "app-resource",
                        "review_note": "Retained for the shipped app icon treatment.",
                    }
                ],
            )
            summary = CHECKER.check(
                root,
                baseline_path=baseline,
                allowlist_path=allowlist,
                verify_source=False,
            )
            self.assertEqual(summary.allowlisted, 1)

            payload = CHECKER.json.loads(allowlist.read_text(encoding="utf-8"))
            payload["entries"][0]["sha256"] = "0" * 64
            allowlist.write_text(CHECKER.json.dumps(payload), encoding="utf-8")
            with self.assertRaises(CHECKER.BinaryEvidenceError):
                CHECKER.check(
                    root,
                    baseline_path=baseline,
                    allowlist_path=allowlist,
                    verify_source=False,
                )

    @staticmethod
    def _git(root: pathlib.Path, *arguments: str) -> str:
        completed = subprocess.run(
            ["git", *arguments],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout

    @classmethod
    def _init_git(cls, root: pathlib.Path) -> None:
        cls._git(root, "init", "-q")
        cls._git(root, "config", "user.email", "binary-evidence@example.invalid")
        cls._git(root, "config", "user.name", "Binary Evidence Tests")

    @staticmethod
    def _manifests(
        root: pathlib.Path,
        records: list[object] | None = None,
        entries: list[dict[str, object]] | None = None,
    ) -> tuple[pathlib.Path, pathlib.Path]:
        baseline = root / "baseline.json"
        allowlist = root / "allowlist.json"
        baseline.write_text(
            CHECKER.json.dumps(
                {
                    "schema_version": CHECKER.SCHEMA_VERSION,
                    "source_commit": CHECKER.BASELINE_COMMIT,
                    "minimum_bytes": CHECKER.MINIMUM_BYTES,
                    "files": [record.as_dict() for record in (records or [])],
                }
            ),
            encoding="utf-8",
        )
        allowlist.write_text(
            CHECKER.json.dumps(
                {"schema_version": CHECKER.SCHEMA_VERSION, "entries": entries or []}
            ),
            encoding="utf-8",
        )
        return baseline, allowlist


if __name__ == "__main__":
    unittest.main()
