"""Real Git edits, worktrees and subprocess boundaries; no gameplay claims."""
from argparse import Namespace
import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import validate_godot
from validation_provenance import SourceRun, check_output_directory, snapshot


class ValidationProvenanceTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name) / "project"
        self.project.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Provenance fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.write("runtime.gd", "extends Node\n")
        self.write("other.gd", "extends Node\n")
        self.write(".gitignore", ".godot/\n__pycache__/\n*.pyc\n")
        self.write("tools/validation/contracts.json", json.dumps({"schema": 1,
            "contracts": [{"id": "fixture", "title": "Fixture", "work": "runner only", "tests": ["fixture_test"]}],
            "scenarios": [{"id": "future", "scope": "Fixture", "limits": "Not executed", "status": "pending", "tests": []}]}))
        self.write("tests/fixture_test.gd", "extends SceneTree\n")
        self.write("tools/check_validation_contracts.py", "print('Source subprocess fixture')\n")
        self.commit()

    def git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.project), *arguments], stderr=subprocess.PIPE).decode().strip()

    def write(self, path, value):
        target = self.project / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(value, encoding="utf-8")

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "Source fixture")

    def runner(self, source_run=None, tests=None):
        args = Namespace(project=self.project, output=self.project.parent / "report", godot="unused",
                         tests=[] if tests is None else tests, skip_import=True, skip_main=True,
                         change_plan={"fixture": True}, source_run=source_run)
        with contextlib.redirect_stdout(io.StringIO()):
            code = validate_godot.validate(args)
        return code, json.loads((args.output / "results.json").read_text())

    def test_clean_and_dirty_stable_runs_have_identifiable_inputs(self):
        clean = snapshot(self.project)
        self.assertEqual(clean["commit"], self.git("rev-parse", "HEAD"))
        self.assertEqual(clean["tree"], self.git("rev-parse", "HEAD^{tree}"))
        self.assertFalse(clean["tracked_worktree_dirty"])
        self.write("runtime.gd", "# staged\n")
        self.git("add", "runtime.gd")
        self.write("other.gd", "# unstaged\n")
        self.write("new\nmodule.gd", "# new\n")
        before_index = (self.project / ".git/index").read_bytes()
        run = SourceRun(self.project)
        run.record("run_end")
        self.assertTrue(run.valid)
        self.assertEqual(run.status, "unchanged")
        self.assertTrue(run.start["tracked_worktree_dirty"])
        self.assertEqual(run.start["untracked_source_count"], 1)
        rows = {r["path"]: r for r in run.start["changes"]}
        self.assertEqual(set(rows), {"runtime.gd", "other.gd", "new\nmodule.gd"})
        self.assertEqual(rows["runtime.gd"]["sha256"], hashlib.sha256(b"# staged\n").hexdigest())
        self.assertEqual(before_index, (self.project / ".git/index").read_bytes(), "Snapshot wrote the index")

    def test_edit_then_restore_still_records_the_intermediate_failure(self):
        run = SourceRun(self.project)
        self.write("runtime.gd", "# changed between commands\n")
        run.record("after:first")
        self.git("checkout", "--", "runtime.gd")
        run.record("run_end")
        self.assertEqual(run.start, run.end)
        self.assertEqual(run.status, "changed")
        self.assertFalse(run.valid)
        self.assertEqual(len(run.events), 2)
        self.assertEqual(run.events[0]["changed_paths"], ["runtime.gd"])

    def test_new_deleted_renamed_and_binary_inputs_change_evidence(self):
        run = SourceRun(self.project)
        self.git("mv", "other.gd", "renamed.gd")
        (self.project / "runtime.gd").unlink()
        (self.project / "binary.data").write_bytes(b"\0\xff\x01")
        run.record("after:work")
        self.assertEqual(set(run.events[0]["changed_paths"]), {"other.gd", "renamed.gd", "runtime.gd", "binary.data"})
        self.assertTrue(run.events[0]["index_changed"])
        self.assertFalse(run.valid)

    def test_commit_during_run_reports_new_tree_and_changed_paths(self):
        run = SourceRun(self.project)
        self.write("runtime.gd", "# committed while testing\n")
        self.commit()
        run.record("after:work")
        self.assertTrue(run.events[0]["revision_changed"])
        self.assertEqual(run.events[0]["changed_paths"], ["runtime.gd"])
        self.assertNotEqual(run.start["tree"], run.end["tree"])

    def test_staging_only_changes_cannot_relabel_the_start(self):
        self.write("runtime.gd", "# dirty input\n")
        run = SourceRun(self.project)
        self.git("add", "runtime.gd")
        run.record("run_end")
        self.assertFalse(run.valid)
        self.assertTrue(run.events[0]["index_changed"])
        self.assertEqual(run.start["changes"], run.end["changes"])

    def test_import_records_new_uid_but_subsequent_edits_fail(self):
        run = SourceRun(self.project)
        self.write("runtime.gd.uid", "uid://abc123\n")
        self.write(".godot/imported/cache.ctex", "generated cache")
        run.record("after:import", allow_import_uids=True)
        self.assertTrue(run.valid)
        self.assertEqual(run.status, "generated_outputs_only")
        self.assertEqual(run.events[0]["generated_uid_paths"], ["runtime.gd.uid"])
        self.assertNotEqual(run.start, run.end)
        self.write("runtime.gd.uid", "uid://changed\n")
        run.record("after:test")
        self.assertFalse(run.valid)
        self.assertEqual(run.events[1]["changed_paths"], ["runtime.gd.uid"])

    def test_uid_exception_cannot_hide_existing_new_source_or_malformed_files(self):
        self.write("runtime.gd.uid", "uid://existing\n")
        self.commit()
        run = SourceRun(self.project)
        self.write("runtime.gd.uid", "uid://modified\n")
        self.write("other.gd.uid", "not a Godot UID\n")
        self.write("untracked.gd", "extends Node\n")
        self.write("untracked.gd.uid", "uid://new\n")
        run.record("after:import", allow_import_uids=True)
        self.assertFalse(run.valid)
        self.assertEqual(run.events[0]["generated_uid_paths"], [])
        self.assertEqual(len(run.events[0]["changed_paths"]), 4)

    def test_new_uid_during_test_is_not_an_import_output(self):
        run = SourceRun(self.project)
        self.write("runtime.gd.uid", "uid://abc123\n")
        run.record("after:test")
        self.assertFalse(run.valid)

    def test_preexisting_untracked_script_can_receive_its_import_uid(self):
        self.write("new_feature.gd", "extends Node\n")
        run = SourceRun(self.project)
        self.write("new_feature.gd.uid", "uid://abc123\n")
        run.record("after:import", allow_import_uids=True)
        self.assertTrue(run.valid)
        self.assertEqual(run.start["untracked_source_count"], 1)
        self.assertEqual(run.end["untracked_source_count"], 2)

    def test_symlink_hashes_link_without_reading_external_target(self):
        link = self.project / "link.gd"
        link.symlink_to("../missing.gd")
        run = SourceRun(self.project)
        self.assertTrue(run.valid)
        row = run.start["changes"][0]
        self.assertTrue(row["symlink"])
        self.assertEqual(row["sha256"], hashlib.sha256(b"../missing.gd").hexdigest())
        link.unlink()
        link.symlink_to("../other.gd")
        run.record("run_end")
        self.assertFalse(run.valid)

    def test_linked_worktree_is_independent(self):
        linked = self.project.parent / "linked"
        self.git("worktree", "add", "-qb", "linked-test", str(linked))
        run = SourceRun(linked)
        self.write("runtime.gd", "# unrelated original checkout\n")
        run.record("run_end")
        self.assertTrue(run.valid)
        self.assertEqual(run.start["untracked_source_count"], 0)

    def test_no_git_nested_project_and_conflicts_are_unavailable(self):
        empty = self.project.parent / "no-git"
        empty.mkdir()
        self.assertEqual(SourceRun(empty).status, "unavailable")
        self.assertEqual(SourceRun(self.project / "tests").status, "unavailable")
        branch = self.git("branch", "--show-current")
        self.git("checkout", "-qb", "conflicting")
        self.write("runtime.gd", "# branch\n")
        self.commit()
        self.git("checkout", "-q", branch)
        self.write("runtime.gd", "# current\n")
        self.commit()
        self.assertNotEqual(subprocess.run(["git", "-C", str(self.project), "merge", "conflicting"], capture_output=True).returncode, 0)
        self.assertEqual(SourceRun(self.project).status, "unavailable")

    def test_missing_git_cannot_claim_a_clean_source(self):
        with patch("validation_provenance.git", side_effect=FileNotFoundError("git unavailable")):
            # changed_paths uses its own module's Git port.
            with patch("validation_plan.git", side_effect=FileNotFoundError("git unavailable")):
                self.assertEqual(SourceRun(self.project).status, "unavailable")

    def test_output_directory_preserves_sources_and_prior_reports(self):
        for output in [self.project, self.project / "new-output"]:
            with self.assertRaisesRegex(ValueError, "outside"): check_output_directory(self.project, output)
        output = self.project.parent / "previous"
        output.mkdir()
        (output / "results.json").write_text("original evidence")
        with self.assertRaisesRegex(ValueError, "preserve"): check_output_directory(self.project, output)
        self.assertEqual((output / "results.json").read_text(), "original evidence")

    def test_runner_keeps_original_revision_and_fails_on_subprocess_edit(self):
        self.write("tools/check_validation_contracts.py", "from pathlib import Path\np=Path(__file__).resolve().parents[1]/'runtime.gd'\np.write_text('# changed by subprocess\\n')\nprint('Source fixture completed')\n")
        self.commit()
        original = self.git("rev-parse", "HEAD")
        code, report = self.runner()
        self.assertEqual(code, 1)
        self.assertTrue(report["checks"][0]["passed"], "Raw subprocess result was rewritten")
        self.assertTrue(report["checks_passed"])
        self.assertFalse(report["passed"])
        self.assertEqual(report["source"]["commit"], original)
        self.assertEqual(report["source_provenance"]["status"], "changed")
        self.assertEqual(report["source_provenance"]["events"][0]["checkpoint"], "after:source_contracts")
        self.assertEqual(report["checks"][0]["command"][0], sys.executable)
        self.assertEqual(json.loads((self.project.parent / "report/source-start.json").read_text()), report["source"])

    def test_stale_selection_stops_before_any_subprocess(self):
        run = SourceRun(self.project)
        self.write("runtime.gd", "# selection no longer describes these inputs\n")
        code, report = self.runner(source_run=run)
        self.assertEqual(code, 1)
        self.assertEqual(report["checks"], [])
        self.assertEqual(report["unexecuted_checks"], ["source_contracts"])
        self.assertFalse(report["passed"])

    def test_subprocess_edit_stops_remaining_game_checks(self):
        self.write("tools/check_validation_contracts.py", "from pathlib import Path\np=Path(__file__).resolve().parents[1]/'runtime.gd'\np.write_text('# source fixture mutation\\n')\n")
        self.commit()
        real_output = subprocess.check_output
        def version_or_git(argv, **kwargs):
            if argv[0] == "unused": return "4.6.3.fixture-version-only"
            return real_output(argv, **kwargs)
        with patch.object(validate_godot.subprocess, "check_output", side_effect=version_or_git):
            code, report = self.runner(tests=["fixture_test"])
        self.assertEqual(code, 1)
        self.assertEqual([c["name"] for c in report["checks"]], ["source_contracts"])
        self.assertEqual(report["unexecuted_checks"], ["fixture_test"])
        self.assertFalse(report["checks_passed"])

    def test_successful_source_only_run_needs_no_engine(self):
        code, report = self.runner()
        self.assertEqual(code, 0)
        self.assertTrue(report["passed"])
        self.assertEqual(report["source_provenance"]["status"], "unchanged")
        self.assertEqual(report["source_provenance"]["source_start"], report["source_provenance"]["source_end"])
        self.assertEqual(report["unexecuted_checks"], [])
        self.assertIsNone(report["godot"])

    def test_missing_process_preserves_failure_and_end_observation(self):
        real_run = subprocess.run
        def unavailable(argv, **kwargs):
            if argv[0] == sys.executable: raise FileNotFoundError("source subprocess unavailable")
            return real_run(argv, **kwargs)
        with patch.object(validate_godot.subprocess, "run", side_effect=unavailable):
            code, report = self.runner()
        self.assertEqual(code, 1)
        self.assertEqual(report["checks"][0]["exit_code"], 127)
        self.assertFalse(report["checks"][0]["passed"])
        self.assertEqual(report["source_provenance"]["observations"][-1]["checkpoint"], "run_end")


if __name__ == "__main__":
    unittest.main()
