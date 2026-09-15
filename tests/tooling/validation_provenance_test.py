"""Actual Git/worktree states and runner failures, including restored edits."""
from argparse import Namespace
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import validation_provenance as provenance
import validate_godot
import validation_contracts_test as contract_fixture


class SourceObservationTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="arch29-source-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.project = self.base / "project"
        self.project.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Provenance fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.write("src/example.gd", "extends Node\n")
        self.write(".gitignore", "ignored/\n")
        self.commit()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.project), *args], stderr=subprocess.PIPE).decode().strip()

    def write(self, path, contents):
        file = self.project / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(contents, encoding="utf-8")
        return file

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture")

    def test_clean_source_has_exact_tree_hashes_and_portable_inventory(self):
        run = provenance.SourceRun(self.project)
        self.assertFalse(run.blocked, run.start)
        self.assertEqual(run.start["commit"], self.git("rev-parse", "HEAD"))
        self.assertEqual(run.start["tree"], self.git("rev-parse", "HEAD^{tree}"))
        self.assertEqual(next(r for r in run.start["files"] if r["path"] == "src/example.gd")["sha256"],
                         hashlib.sha256(b"extends Node\n").hexdigest())
        run.observe("unchanged")
        self.assertEqual(run.current["bytes_hashed"], 0)
        run.observe("finish", force=True)
        self.assertGreater(run.current["bytes_hashed"], 0)
        self.assertEqual(run.start["source_sha256"], run.current["source_sha256"])
        out = self.base / "report"
        out.mkdir()
        run.begin_report(out)
        report = run.write_report(out)
        self.assertTrue(report["reusable"])
        for row in report["manifests"].values():
            self.assertEqual(row["sha256"], hashlib.sha256((out / row["path"]).read_bytes()).hexdigest())
        other = self.base / "other"
        self.git("worktree", "add", "--detach", str(other), "HEAD")
        self.assertEqual(provenance.SourceRun(other).start["source_sha256"], run.start["source_sha256"])

    def _handle_stat(self, real, **changes):
        names = ("st_dev", "st_ino", "st_mode", "st_size", "st_mtime_ns", "st_ctime_ns")
        return SimpleNamespace(**{**{name: getattr(real, name) for name in names}, **changes})

    def test_windows_path_and_handle_ctime_can_use_different_clocks(self):
        real_fstat = os.fstat
        def handle_stat(fd):
            real = real_fstat(fd)
            return self._handle_stat(real, st_ctime_ns=real.st_ctime_ns + 2_000_000)
        with patch.object(provenance, "WINDOWS", True), patch.object(os, "fstat", side_effect=handle_stat):
            run = provenance.SourceRun(self.project)
            self.assertFalse(run.blocked, run.start)
            run.observe("finish", force=True)
            self.assertFalse(run.blocked, run.current)
        row = next(row for row in run.current["files"] if row["path"] == "src/example.gd")
        self.assertEqual(row["sha256"], hashlib.sha256(b"extends Node\n").hexdigest())

    def test_windows_different_file_handle_is_still_rejected(self):
        real_fstat = os.fstat
        def handle_stat(fd):
            real = real_fstat(fd)
            return self._handle_stat(real, st_ino=real.st_ino + 1)
        with patch.object(provenance, "WINDOWS", True), patch.object(os, "fstat", side_effect=handle_stat):
            run = provenance.SourceRun(self.project)
        self.assertTrue(run.blocked)
        self.assertIn("changed while opening", run.start["error"])

    def test_windows_handle_ctime_change_during_read_is_still_rejected(self):
        real_fstat = os.fstat
        calls = 0
        def handle_stat(fd):
            nonlocal calls
            calls += 1
            real = real_fstat(fd)
            return self._handle_stat(real, st_ctime_ns=real.st_ctime_ns + calls)
        with patch.object(provenance, "WINDOWS", True), patch.object(os, "fstat", side_effect=handle_stat):
            run = provenance.SourceRun(self.project)
        self.assertTrue(run.blocked)
        self.assertIn("changed while hashing", run.start["error"])

    def test_staged_unstaged_untracked_and_deleted_sources_are_captured(self):
        self.write("src/example.gd", "staged\n")
        self.git("add", "src/example.gd")
        self.write("src/example.gd", "actual bytes after staging\n")
        self.write("new\nname.gd", "untracked\n")
        self.write("ignored/cache", "not an input\n")
        run = provenance.SourceRun(self.project)
        rows = {r["path"]: r for r in run.start["files"]}
        self.assertEqual(rows["src/example.gd"]["sha256"], hashlib.sha256(b"actual bytes after staging\n").hexdigest())
        self.assertFalse(rows["new\nname.gd"]["tracked"])
        self.assertNotIn("ignored/cache", rows)
        shutil.rmtree(self.project / "src")
        change = run.observe("deleted")
        self.assertTrue(run.blocked)
        self.assertEqual(change["changes"][0]["after"]["kind"], "missing")

    def test_new_delete_rename_and_executable_change_are_observed(self):
        for mode in ("new", "delete", "rename", "mode"):
            with self.subTest(mode=mode):
                # Every mutation starts from its own observed real state.
                path = self.write("src/example.gd", "base\n")
                run = provenance.SourceRun(self.project)
                if mode == "new": self.write("src/new.gd", "new\n")
                elif mode == "delete": path.unlink()
                elif mode == "rename": path.rename(self.project / "src/renamed.gd")
                else:
                    if os.name == "nt": continue
                    path.chmod(0o755)
                run.observe(mode)
                self.assertTrue(run.blocked)

    def test_index_or_commit_change_is_not_relabelled_as_original_source(self):
        self.write("src/example.gd", "dirty\n")
        run = provenance.SourceRun(self.project)
        self.git("add", "src/example.gd")
        row = run.observe("stage")
        self.assertIn("index_sha256", row["git_changes"])
        self.commit()
        row = run.observe("commit")
        self.assertIn("commit", row["git_changes"])
        self.assertTrue(run.blocked)
        self.assertNotEqual(run.start["commit"], run.current["commit"])

    def test_mutation_then_restore_stays_invalid_even_with_identical_final_bytes(self):
        path = self.project / "src/example.gd"
        original = path.read_bytes()
        run = provenance.SourceRun(self.project)
        path.write_bytes(b"other contents\n")
        path.write_bytes(original)
        row = run.observe("restored")
        self.assertEqual(run.start["source_sha256"], run.current["source_sha256"])
        self.assertTrue(run.blocked)
        self.assertEqual(row["changes"][0]["kind"], "touched_or_replaced")
        run.observe("finish", force=True)
        self.assertTrue(run.blocked)

    def test_changes_during_capture_fail_instead_of_mixing_snapshots(self):
        run = provenance.SourceRun(self.project)
        real_file = run._file
        def mutate(path, force):
            result = real_file(path, force)
            if path == "src/example.gd": self.write(".gitignore", "changed after earlier hash\n")
            return result
        with patch.object(run, "_file", side_effect=mutate):
            row = run.observe("unstable")
        self.assertTrue(run.blocked)
        self.assertEqual(row["status"], "unavailable")

    def test_known_uid_generation_is_recorded_only_during_import(self):
        run = provenance.SourceRun(self.project)
        self.write("src/example.gd.uid", "uid://abcdefgh12345\n")
        row = run.observe("import")
        self.assertFalse(run.blocked)
        self.assertTrue(run.prepared)
        self.assertEqual(row["status"], "import_preparation")
        self.assertNotEqual(run.start["source_sha256"], run.current["source_sha256"])
        self.write("src/example.gd.uid", "uid://other123\n")
        run.observe("import")
        self.assertTrue(run.blocked)

    def test_orphan_uid_new_code_or_unexpected_generation_cannot_be_exempted(self):
        cases = [("orphan.gd.uid", "uid://abcdef\n", "import"),
                 ("src/example.gd.uid", "not a uid\n", "import"),
                 ("src/example.gd.uid", "uid://abcdef\n", "example_test"),
                 ("new.gd", "extends Node\n", "import")]
        for path, contents, phase in cases:
            with self.subTest(path=path, phase=phase):
                target = self.project / path
                target.unlink(missing_ok=True)
                run = provenance.SourceRun(self.project)
                self.write(path, contents)
                run.observe(phase)
                self.assertTrue(run.blocked)
                target.unlink()

    def test_import_descriptor_refresh_requires_identical_bytes_and_import_phase(self):
        self.write("asset.svg", "asset bytes\n")
        descriptor = self.write("asset.svg.import", "import settings\n")
        self.commit()
        run = provenance.SourceRun(self.project)
        descriptor.write_bytes(descriptor.read_bytes())
        self.assertEqual(run.observe("import")["status"], "import_preparation")
        self.assertFalse(run.blocked)
        descriptor.write_bytes(descriptor.read_bytes())
        run.observe("example_test")
        self.assertTrue(run.blocked)
        run = provenance.SourceRun(self.project)
        descriptor.write_text("changed import settings\n")
        run.observe("import")
        self.assertTrue(run.blocked)

    def test_ignored_cache_does_not_change_source_but_link_targets_are_not_claimed(self):
        run = provenance.SourceRun(self.project)
        self.write("ignored/resource.bin", "cache\n")
        run.observe("import")
        self.assertFalse(run.blocked)
        outside = self.base / "external"
        outside.write_text("external bytes\n")
        (self.project / "linked.gd").symlink_to(outside)
        run = provenance.SourceRun(self.project)
        self.assertFalse(run.start["complete"])
        self.assertEqual(next(r for r in run.start["files"] if r["path"] == "linked.gd")["sha256"],
                         hashlib.sha256(os.fsencode(outside)).hexdigest())

    def test_budgets_unversioned_and_conflicts_do_not_produce_a_source_pass(self):
        with patch.object(provenance, "MAX_FILES", 1):
            self.assertTrue(provenance.SourceRun(self.project).blocked)
        with patch.object(provenance, "MAX_FILE_BYTES", 1):
            self.assertTrue(provenance.SourceRun(self.project).blocked)
        self.assertTrue(provenance.SourceRun(self.base).blocked)
        blob = self.git("rev-parse", "HEAD:src/example.gd")
        subprocess.run(["git", "-C", str(self.project), "update-index", "--index-info"],
                       input=f"0 {'0' * 40}\tsrc/example.gd\n100644 {blob} 1\tsrc/example.gd\n".encode(), check=True)
        run = provenance.SourceRun(self.project)
        self.assertTrue(run.blocked)
        self.assertIn("conflicts", run.start["error"])


class RunnerProvenanceTest(unittest.TestCase):
    def setUp(self):
        self.fixture = contract_fixture.ValidationContractsTest()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.project = self.fixture.project
        self.output = self.project.parent / (self.project.name + "-provenance")
        self.addCleanup(shutil.rmtree, self.output, True)

    def run_case(self, action=None, skip_import=True):
        args = Namespace(project=self.project, output=self.output, godot="fixture-engine", tests=["example_test"],
                         skip_import=skip_import, skip_main=True)
        real_run = subprocess.run
        def execute(argv, **kwargs):
            if argv[0] in ("git", sys.executable): return real_run(argv, **kwargs)
            if action is not None: action(argv)
            return subprocess.CompletedProcess(argv, 0)
        with patch.object(validate_godot.subprocess, "check_output", return_value="4.6.3.stable.fixture"), \
                patch.object(validate_godot.subprocess, "run", side_effect=execute), \
                contextlib.redirect_stdout(io.StringIO()):
            code = validate_godot.validate(args)
        return code, json.loads((self.output / "results.json").read_text())

    def test_normal_run_records_start_end_commands_and_completion(self):
        code, report = self.run_case()
        self.assertEqual(code, 0)
        self.assertTrue(report["provenance"]["reusable"])
        self.assertEqual(report["source"], report["provenance"]["start"])
        self.assertEqual(report["provenance"]["start"]["source_sha256"], report["provenance"]["end"]["source_sha256"])
        self.assertTrue(all(r["passed"] for r in report["checks"]))
        self.assertIn("command", report["checks"][1])
        self.assertEqual(json.loads((self.output / "run-start.json").read_text())["status"], "in_progress")
        self.assertFalse((self.output / "results.json.tmp").exists())

    def test_passing_process_on_modified_source_is_a_failed_validation(self):
        def change(_argv):
            (self.project / "tests/example_test.gd").write_text("modified while testing\n")
        code, report = self.run_case(change)
        self.assertEqual(code, 1)
        test = next(r for r in report["checks"] if r["name"] == "example_test")
        self.assertTrue(test["process_passed"])
        self.assertFalse(test["passed"])
        self.assertFalse(report["provenance"]["reusable"])
        self.assertEqual(report["provenance"]["observations"][-2]["status"], "changed")

    def test_new_file_during_final_observation_also_invalidates_run(self):
        real_observe = provenance.SourceRun.observe
        def observe(run, after, force=False):
            if after == "finish": (self.project / "new.gd").write_text("late addition\n")
            return real_observe(run, after, force)
        with patch.object(provenance.SourceRun, "observe", observe):
            code, report = self.run_case()
        self.assertEqual(code, 1)
        self.assertFalse(report["checks"][-1]["passed"])

    def test_timeout_and_interrupt_keep_source_evidence_without_a_pass(self):
        for error in (subprocess.TimeoutExpired("fixture", 1), KeyboardInterrupt()):
            with self.subTest(error=type(error).__name__):
                def interrupt(_argv): raise error
                code, report = self.run_case(interrupt)
                self.assertEqual(code, 1)
                test = next(r for r in report["checks"] if r["name"] == "example_test")
                self.assertEqual(test["exit_code"], 124 if isinstance(error, subprocess.TimeoutExpired) else 130)
                self.assertIn("source_sha256", report["provenance"]["end"])
                shutil.rmtree(self.output)

    def test_existing_report_and_output_inside_sources_are_rejected(self):
        self.run_case()
        before = (self.output / "results.json").read_bytes()
        with self.assertRaisesRegex(ValueError, "new output"):
            self.run_case()
        self.assertEqual((self.output / "results.json").read_bytes(), before)
        self.output = self.project / "reports"
        with self.assertRaisesRegex(ValueError, "outside"):
            self.run_case()
        self.assertFalse(self.output.exists())

    def test_automatic_selection_cannot_outlive_its_source(self):
        self.fixture.manifest["contracts"][0]["tests"] = ["example_test"]
        argv = ["validate_godot", "--project", str(self.project), "--contracts", "example", "--skip-main",
                "--output", str(self.output)]
        select = validate_godot.select_contract_tests
        def changed_selection(*args):
            result = select(*args)
            (self.project / "tests/example_test.gd").write_text("changed after selection\n")
            return result
        with patch.object(sys, "argv", argv), patch.object(validate_godot, "select_contract_tests", changed_selection), \
                patch.object(validate_godot, "validation_editor") as editor, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(validate_godot.main(), 1)
            editor.assert_not_called()
        report = json.loads((self.output / "results.json").read_text())
        self.assertEqual([r["name"] for r in report["checks"]], ["source_integrity"])
        self.assertFalse(report["provenance"]["reusable"])


if __name__ == "__main__":
    unittest.main()
