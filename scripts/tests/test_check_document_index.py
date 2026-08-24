import importlib.util
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECKER_PATH = ROOT / "scripts/check_document_index.py"
SPEC = importlib.util.spec_from_file_location("check_document_index", CHECKER_PATH)
CHECKER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(CHECKER)


class CheckDocumentIndexTests(unittest.TestCase):
    def test_repository_contract_passes(self):
        checked_links, markdown_count, classified_count = CHECKER.check(ROOT)
        self.assertGreaterEqual(checked_links, 1)
        self.assertGreaterEqual(markdown_count, len(CHECKER.CURRENT_ENTRY_POINTS))
        self.assertGreaterEqual(classified_count, 1)

    def test_required_audit_documents_have_explicit_classifications(self):
        expected = {
            "docs/HISTORY_TIMELINE_UX_IMPROVEMENT_SPRINT.md": "active",
            "docs/LIVE_ACTIVITY_PROGRESS_FRESHNESS_STORY.md": "active",
            "docs/MNT-008_IDENTITY_SCHEMA_IMPLEMENTATION_STORY.md": "historical",
            "docs/SLICE_3_9_HISTORY_INTERACTION_POLISH_STORIES.md": "completed",
        }
        for relative_path, classification in expected.items():
            self.assertEqual(CHECKER.CLASSIFICATION_INVENTORY[pathlib.Path(relative_path)], classification)

    def test_settled_authority_map_is_exactly_named(self):
        self.assertEqual(
            tuple(path.as_posix() for path in CHECKER.AUTHORITATIVE_PATHS),
            (
                "PRODUCT.md",
                "docs/ROADMAP.md",
                "BACKLOG.md",
                "docs/MVP_SCOPE.md",
                "DOMAIN_RULES.md",
                "DECISIONS.md",
                "docs/ARCHITECTURE.md",
                "docs/PERSISTENCE_MIGRATIONS.md",
                "AGENTS.md",
                "docs/LOCAL_RELEASE_GATES.md",
            ),
        )

    def test_broken_local_link_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            (root / "README.md").write_text("[missing](missing.md)\n", encoding="utf-8")
            with self.assertRaises(CHECKER.DocumentIndexError):
                CHECKER.check_markdown_links(root, (pathlib.Path("README.md"),))

    def test_root_roadmap_reference_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            (root / "README.md").write_text("`ROADMAP.md`\n", encoding="utf-8")
            with self.assertRaises(CHECKER.DocumentIndexError):
                CHECKER.check_roadmap_references(root)

    def test_incomplete_authority_map_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            index = root / CHECKER.INDEX_PATH
            index.parent.mkdir(parents=True)
            index.write_text("| Product | PRODUCT.md |\n", encoding="utf-8")
            with self.assertRaises(CHECKER.DocumentIndexError):
                CHECKER.check_authority_map(root)

    def test_known_planning_document_cannot_remain_unclassified(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            known_document = pathlib.Path("docs/HISTORY_TIMELINE_UX_IMPROVEMENT_SPRINT.md")
            (root / known_document).parent.mkdir(parents=True)
            (root / known_document).write_text("# Known planning document\n", encoding="utf-8")
            index = root / CHECKER.INDEX_PATH
            index.write_text(
                "| Classification | Document |\n"
                "| --- | --- |\n"
                "|  | [History timeline](HISTORY_TIMELINE_UX_IMPROVEMENT_SPRINT.md) |\n",
                encoding="utf-8",
            )
            with self.assertRaises(CHECKER.DocumentIndexError):
                CHECKER.check_document_inventory(
                    root,
                    {known_document: "active"},
                    enforce_document_set=False,
                )


if __name__ == "__main__":
    unittest.main()
