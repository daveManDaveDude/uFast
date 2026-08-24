import importlib.util
import pathlib
import shutil
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECKER_PATH = ROOT / "scripts/check_system_surface_inventory.py"
SPEC = importlib.util.spec_from_file_location("check_system_surface_inventory", CHECKER_PATH)
CHECKER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(CHECKER)


class CheckSystemSurfaceInventoryTests(unittest.TestCase):
    def _copy_layout_sources(self, root: pathlib.Path) -> None:
        for relative_path in CHECKER.REQUIRED_LAYOUT_SOURCES:
            source = ROOT / relative_path
            destination = root / relative_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)

    def test_repository_contract_passes(self):
        CHECKER.check(ROOT)

    def test_required_family_and_dynamic_island_inventory_is_explicit(self):
        CHECKER.check_layout_inventory(ROOT)
        self.assertEqual(
            CHECKER.SYSTEM_SURFACE_LAYOUT_INVENTORY["widgetFamilies"],
            ("accessoryRectangular", "systemSmall", "systemMedium", "systemLarge"),
        )
        self.assertEqual(
            CHECKER.SYSTEM_SURFACE_LAYOUT_INVENTORY["activityRegions"],
            ("compactLeading", "compactTrailing", "minimal", "expanded"),
        )
        self.assertEqual(
            CHECKER.SYSTEM_SURFACE_LAYOUT_INVENTORY["largeTextConfiguration"],
            "accessibility3",
        )

    def test_missing_layout_source_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            with self.assertRaises(CHECKER.SystemSurfaceInventoryError):
                CHECKER.check_layout_inventory(root)

    def test_missing_widget_family_declaration_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            self._copy_layout_sources(root)
            source = root / "LockScreenWidget/Widget/HomeScreenWidget.swift"
            source.write_text(
                source.read_text(encoding="utf-8").replace(
                    ".systemMedium", ".removedSystemMedium"
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CHECKER.SystemSurfaceInventoryError,
                "systemMedium",
            ):
                CHECKER.check_layout_inventory(root)

    def test_missing_live_activity_region_declaration_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            self._copy_layout_sources(root)
            source = root / "LockScreenWidget/Widget/ActiveFastActivityWidget.swift"
            source.write_text(
                source.read_text(encoding="utf-8")
                .replace("compactTrailingContent", "removedCompactTrailingContent")
                .replace("compactTrailing:", "removedCompactTrailing:"),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CHECKER.SystemSurfaceInventoryError,
                "compactTrailing",
            ):
                CHECKER.check_layout_inventory(root)

    def test_widget_catalog_membership_is_required(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            (root / "project.yml").write_text(
                "targets:\n"
                "  uFast:\n"
                "    sources:\n"
                "      - path: LockScreenShared\n"
                "    resources:\n"
                "      - path: uFast/Resources/Localizable.xcstrings\n"
                "  uFastLockScreenWidget:\n"
                "    sources:\n"
                "      - path: LockScreenShared\n"
                "    resources:\n"
                "      - path: LockScreenWidget/Widget/FastingBotanical.png\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CHECKER.LOCALIZATION_CHECKER.LocalizationCheckError,
                "widget target",
            ):
                CHECKER.LOCALIZATION_CHECKER.check_system_surface_target_membership(root)


if __name__ == "__main__":
    unittest.main()
