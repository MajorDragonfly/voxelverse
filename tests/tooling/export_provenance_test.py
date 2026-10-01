"""Export orchestration with real Git and child processes, no gameplay claims.

The child is an explicit engine/package fixture: it creates a small fake PCK,
emits acceptance markers and can change source files at exact process phases.
"""
from argparse import Namespace
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import validate_export
from validation_provenance import SourceRun

DRIVER = r'''
import json, os, subprocess, sys
from pathlib import Path
phase, argv = sys.argv[1], sys.argv[2:]
config = json.loads(Path(__file__).with_name("config.json").read_text())
root = Path(config["project"])
if config.get("phase") == phase:
    source = root / "source.gd"
    action = config["action"]
    if action == "uid":
        (root / "source.gd.uid").write_text("uid://abcdefgh12345\n")
    elif action == "restore":
        original = source.read_bytes()
        source.write_bytes(b"temporary edit\n")
        source.write_bytes(original)
    else:
        source.write_text("edited during acceptance\n")
        if action == "commit":
            subprocess.run(["git", "-C", str(root), "add", "source.gd"], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "During export"], check=True)
if phase == "version":
    print(config.get("version", "4.6.3.stable.fixture"))
    sys.exit(0)
if phase == "release_export":
    executable = Path(argv[-1])
    executable.write_bytes(b"Explicit test fixture, not a native executable")
    executable.with_suffix(".pck").write_bytes(b"Explicit test fixture, not a Godot PCK")
if "--script" in argv and Path(argv[argv.index("--script")+1]).stem == "export_runtime_probe":
    seed, report, notices = argv[-3:]
    family = {"15838": "verdant", "63352": "autumn", "23757": "violet"}[seed]
    Path(report).write_text(json.dumps({"passed": True, "loaded_meshes": 63,
        "flora_color_family": family, "user_data_dir": os.environ["XDG_DATA_HOME"],
        "executable": argv[0]}))
    Path(notices).write_text("Fixture notices\n")
print("PLANET_LAB_READY MENU_INPUT_PASSED FRONTEND_PASSED PAUSE_MENU_PASSED SPHERICAL_CAMPAIGN_RUNTIME_PASSED "
      "SPHERICAL_CREATURE_PASSED SPHERICAL_GAMEPLAY_PASSED BODY_TRAVEL_PASSED SPHERICAL_EGG_PRODUCTION_PASSED")
'''


class ExportProvenanceTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="export-provenance-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.project = self.base / "project"
        self.project.mkdir()
        self.output = self.base / "report"
        self.driver = self.base / "driver.py"
        self.driver.write_text(DRIVER)
        self.engine = self.base / "engine" / "GodotFixture"
        self.engine.parent.mkdir()
        self.engine.write_text("Explicit engine fixture")
        self.git("init", "-q")
        self.git("config", "user.name", "Export fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.write("source.gd", "original source\n")
        self.write("tests/fixtures/home_group_pr20.json", "{}\n")
        self.write("tools/export_runtime_probe.gd", "extends SceneTree\n")
        for name in validate_export.PACKAGED_TESTS:
            self.write(f"tests/{name}.gd", "extends SceneTree\n")
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture")
        self.head = self.git("rev-parse", "HEAD").strip()
        self.tree = self.git("rev-parse", "HEAD^{tree}").strip()
        self.calls = []

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.project), *args], text=True, stderr=subprocess.PIPE)

    def write(self, name, data):
        path = self.project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)

    def run_case(self, phase=None, action=None, failure=None, version=None):
        config = {"project": str(self.project), "phase": phase, "action": action}
        if version is not None:
            config["version"] = version
        (self.base / "config.json").write_text(json.dumps(config))
        args = Namespace(godot=str(self.engine), project=self.project, output=self.output,
                         platform="windows" if os.name == "nt" else "linux", skip_import=False)
        real_run = subprocess.run

        def execute(command, **kwargs):
            if command[0] == "git":
                return real_run(command, **kwargs)
            current = ("version" if "--version" in command else "import" if "--import" in command else
                       "release_export" if "--export-release" in command else
                       Path(command[command.index("--script")+1]).stem if "--script" in command else "native")
            self.calls.append(current)
            if failure is not None and current == phase:
                raise failure
            return real_run([sys.executable, str(self.driver), current, *command], **kwargs)

        with patch.object(validate_export.subprocess, "run", side_effect=execute), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            code = validate_export.validate(args)
        return code, json.loads((self.output / "results.json").read_text())

    def assert_no_package(self):
        self.assertEqual(list(self.output.glob("*.zip*")), [])
        self.assertFalse((self.output / "SHA256SUMS.txt").exists())

    def test_complete_pipeline_binds_archive_build_info_and_manifests_to_source(self):
        code, report = self.run_case()
        self.assertEqual(code, 0)
        self.assertTrue(report["passed"] and report["complete"] and report["provenance"]["reusable"])
        self.assertEqual(report["source"]["commit"], self.head)
        self.assertEqual(report["source"]["tree"], self.tree)
        self.assertEqual(report["provenance"]["status"], "stable")
        self.assertTrue(next(check for check in report["checks"] if check["name"] == "packaged_pause_menu")["passed"])
        archive = self.output / report["archive"]["name"]
        self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(), report["archive"]["sha256"])
        with zipfile.ZipFile(archive) as package:
            build = json.loads(package.read("voxelverse/BUILD_INFO.json"))
        self.assertEqual(build["source"], report["source"])
        self.assertEqual(build["export_source"], report["export_source"])
        self.assertEqual(build["validation_source"]["source_sha256"], report["provenance"]["end"]["source_sha256"])
        self.assertTrue(build["source_inputs_complete"])
        for manifest in report["provenance"]["manifests"].values():
            self.assertEqual(hashlib.sha256((self.output / manifest["path"]).read_bytes()).hexdigest(), manifest["sha256"])
        self.assertEqual(json.loads((self.output / "run-start.json").read_text())["source"]["commit"], self.head)

    def test_import_preparation_preserves_both_original_and_exported_input_identity(self):
        code, report = self.run_case("import", "uid")
        self.assertEqual(code, 0)
        self.assertEqual(report["provenance"]["status"], "prepared")
        self.assertNotEqual(report["source"]["source_sha256"], report["export_source"]["source_sha256"])
        self.assertEqual(report["export_source"]["source_sha256"], report["provenance"]["end"]["source_sha256"])

    def test_commit_during_export_stops_before_native_processes(self):
        code, report = self.run_case("release_export", "commit")
        self.assertEqual(code, 1)
        self.assertEqual(report["source"]["commit"], self.head)
        self.assertNotEqual(report["provenance"]["end"]["commit"], self.head)
        check = next(r for r in report["checks"] if r["name"] == "release_export")
        self.assertTrue(check["process_passed"])
        self.assertFalse(check["passed"])
        self.assertNotIn("native", self.calls)
        self.assert_no_package()

    def test_change_during_native_acceptance_stops_following_probes(self):
        code, report = self.run_case("native", "edit")
        self.assertEqual(code, 1)
        self.assertEqual(self.calls.count("native"), 1)
        self.assertNotIn("body_identity_test", self.calls)
        self.assertFalse(report["provenance"]["reusable"])
        self.assert_no_package()

    def test_restored_source_during_probe_remains_invalid(self):
        code, report = self.run_case("body_identity_test", "restore")
        self.assertEqual(code, 1)
        self.assertEqual(report["source"]["source_sha256"], report["provenance"]["end"]["source_sha256"])
        self.assertNotIn("far_simulation_test", self.calls)
        self.assertFalse(report["provenance"]["reusable"])
        self.assert_no_package()

    def test_last_source_gate_withholds_zip_and_checksum_after_late_change(self):
        original = SourceRun.observe

        def observe(run, phase, force=False):
            if phase == "finish":
                self.write("source.gd", "changed after archive creation\n")
            return original(run, phase, force)

        with patch.object(SourceRun, "observe", observe):
            code, report = self.run_case()
        self.assertEqual(code, 1)
        self.assertTrue(report["complete"])
        self.assertFalse(report["checks"][-1]["passed"])
        self.assert_no_package()

    def test_timeout_preserves_progress_log_source_end_and_exit_code(self):
        code, report = self.run_case("release_export", failure=subprocess.TimeoutExpired("fixture", 1, output=b"export progress"))
        self.assertEqual(code, 1)
        check = next(r for r in report["checks"] if r["name"] == "release_export")
        self.assertEqual(check["exit_code"], 124)
        self.assertIn("export progress", (self.output / "logs/release_export.log").read_text())
        self.assertEqual(report["provenance"]["end"]["commit"], self.head)
        self.assert_no_package()

    def test_interrupt_preserves_diagnostics_without_publishing_package(self):
        code, report = self.run_case("native", failure=KeyboardInterrupt())
        self.assertEqual(code, 1)
        check = next(r for r in report["checks"] if r["name"] == "packaged_main")
        self.assertEqual(check["exit_code"], 130)
        self.assertFalse(report["complete"])
        self.assert_no_package()

    def test_wrong_engine_version_has_start_and_final_failure_report(self):
        code, report = self.run_case(version="4.5.stable.fixture")
        self.assertEqual(code, 1)
        self.assertIn("Expected Godot 4.6.3", report["error"])
        self.assertEqual(self.calls, ["version"])
        self.assertEqual(report["source"]["commit"], self.head)
        self.assert_no_package()

    def test_engine_preparation_change_cannot_relabel_the_start(self):
        code, report = self.run_case("version", "edit")
        self.assertEqual(code, 1)
        self.assertEqual(self.calls, ["version"])
        self.assertIn("engine_version", report["error"])
        self.assert_no_package()

    def test_existing_and_internal_output_are_preserved_before_launch(self):
        self.output.mkdir()
        sentinel = self.output / "results.json"
        sentinel.write_text("previous evidence")
        with self.assertRaisesRegex(ValueError, "new output"):
            self.run_case()
        self.assertEqual(sentinel.read_text(), "previous evidence")
        self.output = self.project / "reports"
        with self.assertRaisesRegex(ValueError, "outside"):
            self.run_case()
        self.assertFalse(self.output.exists())
        self.assertEqual(self.calls, [])

    def test_missing_git_blocks_before_engine_and_records_unavailable_source(self):
        (self.project / ".git").rename(self.base / "git-removed")
        code, report = self.run_case()
        self.assertEqual(code, 1)
        self.assertEqual(self.calls, [])
        self.assertFalse(report["source"]["available"])
        self.assertFalse(report["provenance"]["reusable"])
        self.assert_no_package()

    def test_checksum_write_failure_removes_release_archive(self):
        original = Path.write_text

        def write(path, *args, **kwargs):
            if path.name == "SHA256SUMS.txt":
                raise OSError("Fixture checksum write failure")
            return original(path, *args, **kwargs)

        with patch.object(Path, "write_text", write):
            code, report = self.run_case()
        self.assertEqual(code, 1)
        self.assertIn("checksum write failure", report["error"])
        self.assertFalse(report["provenance"]["reusable"])
        self.assert_no_package()


if __name__ == "__main__":
    unittest.main()
