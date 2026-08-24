import importlib.util
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECKER_PATH = ROOT / "scripts/check_ui_test_launch_arguments.py"
SPEC = importlib.util.spec_from_file_location("check_ui_test_launch_arguments", CHECKER_PATH)
CHECKER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(CHECKER)


class CheckUITestLaunchArgumentsTests(unittest.TestCase):
    def test_repository_contract_passes(self):
        CHECKER.check(ROOT)

    def test_supported_direct_flag_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = pathlib.Path(temporary)
            production = fixture / CHECKER.PRODUCTION_PATH
            builder = fixture / CHECKER.BUILDER_PATH
            ui_tests = fixture / CHECKER.UI_TESTS_PATH
            production.parent.mkdir(parents=True)
            builder.parent.mkdir(parents=True)
            ui_tests.mkdir(parents=True, exist_ok=True)
            production.write_text('arguments.contains("--ui-testing")\n', encoding="utf-8")
            builder.write_text('let flags = ["--ui-testing"]\n', encoding="utf-8")
            (ui_tests / "Example.swift").write_text(
                'let arguments = ["--ui-testing"]\n', encoding="utf-8"
            )
            with self.assertRaises(CHECKER.LaunchArgumentCheckError):
                CHECKER.check(fixture)


if __name__ == "__main__":
    unittest.main()
