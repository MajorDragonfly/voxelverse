"""Exercise real catalog failures and stop the runner before any game process."""
from argparse import Namespace
import contextlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import check_validation_contracts as contracts
import validate_godot


class ValidationContractsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name)
        for directory in ["tests", "tools/validation", "tools/localization", "localization"]:
            (self.project / directory).mkdir(parents=True, exist_ok=True)
        for name in ["tools/check_validation_contracts.py", "tools/localization/catalog.py"]:
            shutil.copyfile(contracts.ROOT / name, self.project / name)
        (self.project / "tests/example_test.gd").write_text("extends SceneTree\n", encoding="utf-8")
        self.manifest = {"schema": 1, "contracts": [
            {"id": "example", "title": "Example", "work": "ARCH-29", "tests": ["example_test"]}],
            "scenarios": [{"id": "future", "status": "pending", "tests": [],
                           "scope": "Future data", "limits": "Not implemented"}]}
        self.save_manifest()
        self.catalog = {"schema": 1, "locales": {
            "de": {"name": "Deutsch", "plural_forms": "nplurals=2; plural=(n != 1);"},
            "en": {"name": "English", "plural_forms": "nplurals=2; plural=(n != 1);"}},
            "messages": [{"key": "HELLO", "de": "Hallo {name}", "en": "Hello {name}"}]}
        self.save_catalog()
        subprocess.run([sys.executable, str(self.project / "tools/localization/catalog.py")],
                       check=True, capture_output=True)

    def save_manifest(self):
        (self.project / contracts.MANIFEST).write_text(json.dumps(self.manifest), encoding="utf-8")

    def save_catalog(self):
        (self.project / "localization/catalog.json").write_text(json.dumps(self.catalog), encoding="utf-8")

    def snapshot(self):
        return {p.name: p.read_bytes() for p in (self.project / "localization").iterdir()}

    def test_valid_catalog_is_read_only_and_pending_is_not_a_pass(self):
        before = self.snapshot()
        report = contracts.check(self.project)
        self.assertEqual(report["registered_tests"], 1)
        self.assertEqual(report["scenario_counts"], {"pending": 1})
        self.assertEqual(report["kind"], "source_contract")
        self.assertEqual(self.snapshot(), before)

    def test_new_nested_test_requires_contract_registration(self):
        (self.project / "tests/new").mkdir()
        (self.project / "tests/new/feature_test.gd").write_text("extends SceneTree\n")
        with self.assertRaisesRegex(ValueError, "Unregistered test: new/feature_test"):
            contracts.read_contracts(self.project)

    def test_removed_test_is_not_silently_skipped(self):
        (self.project / "tests/example_test.gd").unlink()
        with self.assertRaisesRegex(ValueError, "Missing test: example_test"):
            contracts.read_contracts(self.project)

    def test_duplicate_owner_rejected(self):
        self.manifest["contracts"].append({"id": "other", "title": "Other", "work": "M10",
                                           "tests": ["example_test"]})
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, "Duplicate test owner"):
            contracts.read_contracts(self.project)

    def test_future_manifest_is_not_rewritten(self):
        self.manifest["schema"] = 99
        self.save_manifest()
        before = (self.project / contracts.MANIFEST).read_bytes()
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            contracts.read_contracts(self.project)
        self.assertEqual((self.project / contracts.MANIFEST).read_bytes(), before)

    def test_scenario_cannot_claim_implementation_without_tests(self):
        self.manifest["scenarios"][0]["status"] = "implemented"
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, "need evidence"):
            contracts.read_contracts(self.project)

    def test_scenario_must_reference_registered_test(self):
        self.manifest["scenarios"][0].update(status="partial", tests=["missing_test"])
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, "Unknown scenario test"):
            contracts.read_contracts(self.project)

    def test_stale_generated_resources_rejected_without_repair(self):
        for resource in ["de.po", "en.po", "catalogs.gd"]:
            with self.subTest(resource=resource):
                path = self.project / "localization" / resource
                original = path.read_bytes()
                path.write_bytes(original + b"stale\n")
                before = self.snapshot()
                with self.assertRaisesRegex(ValueError, "Stale resource: " + resource):
                    contracts.check(self.project)
                self.assertEqual(self.snapshot(), before)
                path.write_bytes(original)

    def test_placeholder_and_missing_translation_fail(self):
        for value, message in [("Hello {wrong}", "Placeholders differ"), ("", "Missing en")]:
            with self.subTest(value=value):
                self.catalog["messages"][0]["en"] = value
                self.save_catalog()
                before = self.snapshot()
                with self.assertRaisesRegex(ValueError, message):
                    contracts.check(self.project)
                self.assertEqual(self.snapshot(), before)

    def run_without_game(self, tests):
        args = Namespace(project=self.project, output=self.project / "results", godot="unused-godot",
                         tests=tests, skip_import=True, skip_main=True)
        real_run = subprocess.run

        def only_source(argv, **kwargs):
            self.assertEqual(argv[0], sys.executable, "Runner started Godot after a source failure")
            return real_run(argv, **kwargs)

        with patch.object(validate_godot.subprocess, "check_output", return_value="4.6.3.stable.test"), \
                patch.object(validate_godot.subprocess, "run", side_effect=only_source), \
                patch.object(validate_godot, "revision", return_value={"commit": "fixture"}), \
                contextlib.redirect_stdout(io.StringIO()):
            status = validate_godot.validate(args)
        return status, json.loads((args.output / "results.json").read_text())

    def test_skip_import_still_runs_source_gate(self):
        (self.project / "localization/en.po").write_text("stale\n")
        status, result = self.run_without_game(["example_test"])
        self.assertEqual(status, 1)
        self.assertEqual([c["name"] for c in result["checks"]], ["source_contracts"])
        self.assertFalse(result["checks"][0]["passed"])
        self.assertEqual(result["checks"][0]["kind"], "source_contract")

    def test_unknown_requested_test_stops_before_game(self):
        status, result = self.run_without_game(["typo_test"])
        self.assertEqual(status, 1)
        self.assertEqual(result["checks"][-1]["name"], "test_selection")

    def test_explicit_empty_selection_is_preserved(self):
        status, result = self.run_without_game([])
        self.assertEqual(status, 0)
        self.assertEqual(result["selected_tests"], [])
        self.assertEqual(result["execution"], "headless_source_project")
        self.assertEqual(len(result["checks"]), 1)


if __name__ == "__main__":
    unittest.main()
