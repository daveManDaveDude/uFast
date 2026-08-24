import importlib.util
import json
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECKER_PATH = ROOT / "scripts/check_localized_literals.py"
SPEC = importlib.util.spec_from_file_location("check_localized_literals", CHECKER_PATH)
CHECKER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(CHECKER)


class CheckLocalizedLiteralsTests(unittest.TestCase):
    def test_repository_contract_passes(self):
        CHECKER.check(ROOT)

    def test_today_persistence_boundary_is_in_frozen_scope(self):
        self.assertIn(
            pathlib.Path("uFast/Persistence/TodayDataProvider.swift"),
            CHECKER.MIGRATED_PATHS,
        )

    def test_history_grouping_domain_is_in_catalog_inventory(self):
        relative_path = pathlib.Path("uFast/Domain/TemporalEventGrouping.swift")
        self.assertIn(relative_path, CHECKER.MNT010C_INVENTORY_PATHS)
        self.assertIn(relative_path, CHECKER.HISTORY_GROUPING_COPY_PATHS)

    def test_grouping_copy_check_rejects_domain_owned_family_copy(self):
        self.assertEqual(
            CHECKER.grouping_copy_violations([(4, 'return "food events"')]),
            [(4, 'return "food events"')],
        )

    def test_grouping_copy_check_allows_catalog_backed_title_resolution(self):
        self.assertEqual(
            CHECKER.grouping_copy_violations(
                [(4, "textResolver(.historyGroupTitle(count: 2, family: .food))")]
            ),
            [],
        )

    def test_negative_control_rejects_new_user_facing_literal(self):
        violations = CHECKER.literal_violations([(4, 'Text("Uncatalogued copy")')])
        self.assertEqual(violations, [(4, 'Text("Uncatalogued copy")')])

    def test_negative_control_rejects_multiline_user_facing_literal(self):
        violations = CHECKER.literal_violations(
            [
                (4, "Text("),
                (5, '    """Uncatalogued multiline copy"""'),
                (6, ")"),
            ]
        )
        self.assertEqual(violations, [(5, '"""Uncatalogued multiline copy"""')])

    def test_negative_control_rejects_indirect_user_facing_literal(self):
        violations = CHECKER.literal_violations(
            [
                (4, 'let title = "Uncatalogued indirect copy"'),
                (5, "Text(title)"),
            ]
        )
        self.assertEqual(
            {line_number for line_number, _ in violations},
            {4, 5},
        )

    def test_non_copy_literals_are_not_tainted_by_identifier_use(self):
        violations = CHECKER.literal_violations(
            [
                (4, 'let identifier = "food.save"'),
                (5, ".accessibilityIdentifier(identifier)"),
            ]
        )
        self.assertEqual(violations, [])

    def test_indirect_formatter_check_rejects_each_legacy_duration_formatter(self):
        for formatter in CHECKER.LEGACY_HISTORY_FORMATTERS:
            with self.subTest(formatter=formatter):
                self.assertEqual(
                    CHECKER.indirect_formatter_violations(
                        [(7, f"Text({formatter}.string(from: duration))")]
                    ),
                    [(7, f"Text({formatter}.string(from: duration))")],
                )

    def test_indirect_formatter_check_allows_catalog_owned_duration_formatter(self):
        self.assertEqual(
            CHECKER.indirect_formatter_violations(
                [
                    (
                        7,
                        "HistoryTextFormatting.duration(seconds: duration, resolver: resolve)",
                    )
                ]
            ),
            [],
        )

    def test_documented_exception_is_narrow(self):
        self.assertEqual(
            CHECKER.literal_violations(
                [
                    (1, "// localization-exception: system-provided copy"),
                    (2, 'Text("System-provided copy")'),
                ]
            ),
            [],
        )

    def test_missing_key_fails_catalog_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            catalog = root / CHECKER.CATALOG_PATH
            app_text = root / CHECKER.APP_TEXT_PATH
            catalog.parent.mkdir(parents=True)
            app_text.parent.mkdir(parents=True)
            catalog.write_text(
                json.dumps({"sourceLanguage": "en", "strings": {}}), encoding="utf-8"
            )
            app_text.write_text('resource("missing.key", "Missing", "test")', encoding="utf-8")
            with self.assertRaises(CHECKER.LocalizationCheckError):
                CHECKER.validate_catalog(root)

    def test_line_wrapped_resource_missing_key_fails_catalog_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            catalog = root / CHECKER.CATALOG_PATH
            app_text = root / CHECKER.APP_TEXT_PATH
            catalog.parent.mkdir(parents=True)
            app_text.parent.mkdir(parents=True)
            catalog.write_text(
                json.dumps({"sourceLanguage": "en", "strings": {}}), encoding="utf-8"
            )
            app_text.write_text(
                'resource\n'
                '    (\n'
                '        "line-wrapped.missing-key",\n'
                '        "Missing",\n'
                '        "test"\n'
                '    )',
                encoding="utf-8",
            )
            with self.assertRaises(CHECKER.LocalizationCheckError):
                CHECKER.validate_catalog(root)

    def test_conditional_resource_keys_are_all_required(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            catalog = root / CHECKER.CATALOG_PATH
            app_text = root / CHECKER.APP_TEXT_PATH
            catalog.parent.mkdir(parents=True)
            app_text.parent.mkdir(parents=True)
            catalog.write_text(
                json.dumps(
                    {
                        "sourceLanguage": "en",
                        "strings": {
                            "conditional.false": {
                                "localizations": {"en": {"stringUnit": {"value": "False"}}}
                            }
                        },
                    }
                ),
                encoding="utf-8",
            )
            app_text.write_text(
                'resource(isEnabled ? "conditional.true" : "conditional.false", "Value", "test")',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(CHECKER.LocalizationCheckError, "conditional.true"):
                CHECKER.validate_catalog(root)

    def test_dynamic_resource_key_is_rejected(self):
        with self.assertRaisesRegex(CHECKER.LocalizationCheckError, "literal key"):
            CHECKER.app_text_keys('resource(makeKey("dynamic.key"), "Value", "test")')

    def test_stale_catalog_key_fails_catalog_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            catalog = root / CHECKER.CATALOG_PATH
            app_text = root / CHECKER.APP_TEXT_PATH
            catalog.parent.mkdir(parents=True)
            app_text.parent.mkdir(parents=True)
            catalog.write_text(
                json.dumps(
                    {
                        "sourceLanguage": "en",
                        "strings": {
                            "used.key": {
                                "localizations": {"en": {"stringUnit": {"value": "Used"}}}
                            },
                            "stale.key": {
                                "localizations": {"en": {"stringUnit": {"value": "Stale"}}}
                            },
                        },
                    }
                ),
                encoding="utf-8",
            )
            app_text.write_text('resource("used.key", "Used", "test")', encoding="utf-8")
            with self.assertRaisesRegex(CHECKER.LocalizationCheckError, "stale.key"):
                CHECKER.validate_catalog(root)

    def test_catalog_plural_missing_other_form_fails_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            catalog = root / CHECKER.CATALOG_PATH
            app_text = root / CHECKER.APP_TEXT_PATH
            catalog.parent.mkdir(parents=True)
            app_text.parent.mkdir(parents=True)
            catalog.write_text(
                json.dumps(
                    {
                        "sourceLanguage": "en",
                        "strings": {
                            "plural.key": {
                                "localizations": {
                                    "en": {
                                        "variations": {
                                            "plural": {"one": {"stringUnit": {"value": "One"}}}
                                        }
                                    }
                                }
                            }
                        },
                    }
                ),
                encoding="utf-8",
            )
            app_text.write_text('resource("plural.key", "One", "test")', encoding="utf-8")
            with self.assertRaisesRegex(CHECKER.LocalizationCheckError, "plural one/other"):
                CHECKER.validate_catalog(root)


if __name__ == "__main__":
    unittest.main()
