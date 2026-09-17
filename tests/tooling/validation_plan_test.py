"""Real Git deltas and CLI boundaries: no omissions or synthetic test passes."""
import contextlib
import copy
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import validate_godot
from check_validation_contracts import read_contracts
from validation_plan import build_plan, read_rules, select_changes, summarize_plan


class ValidationPlanTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name) / "project"
        self.project.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Validation fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.manifest = {"schema": 1, "contracts": [
            {"id": "audio", "title": "Audio", "work": "fixture", "tests": ["audio_test"]},
            {"id": "ui", "title": "UI", "work": "fixture", "tests": ["ui_test", "extra_test"]}],
            "scenarios": [{"id": "future", "scope": "pending", "limits": "not implemented", "status": "pending", "tests": []}]}
        self.rules = {"schema": 1, "documentation": ["docs/*.md"], "full": ["core/*", "tools/*"], "rules": [
            {"id": "sound", "paths": ["audio/*"], "contracts": ["audio", "ui"]},
            {"id": "screen", "paths": ["ui/*"], "contracts": ["ui"]}]}
        self.write("tools/validation/contracts.json", json.dumps(self.manifest))
        self.write("tools/validation/selection_rules.json", json.dumps(self.rules))
        for path in ["tests/audio_test.gd", "tests/ui_test.gd", "tests/extra_test.gd", "audio/sound.gd", "ui/view.gd", "core/save.gd"]:
            self.write(path, "extends SceneTree\n")
        self.write("docs/notes.md", "Original notes\n")
        self.write(".gitignore", "ignored/\n")
        self.commit()
        self.base = self.git("rev-parse", "HEAD").strip()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.project), *args], text=True, stderr=subprocess.PIPE)

    def write(self, path, text):
        file = self.project / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text, encoding="utf-8")

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture checkpoint")

    def plan(self):
        return build_plan(self.project, self.base)

    def cli(self, flags):
        output = io.StringIO()
        with patch.object(sys, "argv", ["validate_godot", "--project", str(self.project), *flags]), contextlib.redirect_stdout(output):
            result = validate_godot.main()
        return result, output.getvalue()

    def test_clean_checkout_is_a_plan_not_a_pass(self):
        plan = self.plan()
        self.assertEqual(plan["scope"], "unchanged")
        self.assertEqual(plan["selected_tests"], [])
        self.assertFalse(plan["tests_executed"])
        self.assertNotIn("passed", plan)

    def test_committed_staged_unstaged_and_new_files_are_all_included(self):
        self.write("audio/sound.gd", "# committed\n")
        self.commit()
        self.write("ui/view.gd", "# staged\n")
        self.git("add", "ui/view.gd")
        self.write("docs/notes.md", "unstaged\n")
        self.write("audio/new sound.gd", "# untracked\n")
        self.write("ignored/temporary.gd", "# excluded by Git\n")
        plan = self.plan()
        paths = {r["path"] for r in plan["source"]["changes"]}
        self.assertEqual(paths, {"audio/sound.gd", "ui/view.gd", "docs/notes.md", "audio/new sound.gd"})
        self.assertEqual(plan["selected_tests"], ["audio_test", "extra_test", "ui_test"])
        self.assertNotEqual(plan["source"]["head_commit"], self.base)

    def test_rename_preserves_both_old_and_new_domains(self):
        self.git("mv", "audio/sound.gd", "ui/moved.gd")
        plan = self.plan()
        self.assertEqual({r["status"] for r in plan["source"]["changes"]}, {"A", "D"})
        self.assertIn("audio_test", plan["selected_tests"])
        self.assertEqual(len(plan["decisions"]), 2)

    def test_newline_filename_is_not_split_or_quoted_by_git(self):
        path = "audio/a\nstrange.gd"
        self.write(path, "# new\n")
        self.assertEqual(self.plan()["source"]["changes"][0]["path"], path)

    def test_unknown_file_and_shared_save_expand_to_full(self):
        self.write("unknown_plugin/runtime.gd", "new module\n")
        plan = self.plan()
        self.assertEqual(plan["scope"], "full")
        self.assertTrue(plan["requires_main"])
        self.assertEqual(plan["decisions"][0]["reason"], "unmapped_path_requires_full")
        self.write("core/save.gd", "changed writer\n")
        self.assertIn("shared_infrastructure_requires_full", [r["reason"] for r in self.plan()["decisions"]])

    def test_direct_test_change_runs_only_that_registered_test(self):
        self.write("tests/ui_test.gd", "# changed assertion\n")
        self.assertEqual(self.plan()["selected_tests"], ["ui_test"])
        self.assertFalse(self.plan()["requires_main"])

    def test_new_registered_test_is_included_without_second_mapping(self):
        self.write("tests/added_test.gd", "extends SceneTree\n")
        self.manifest["contracts"][0]["tests"].append("added_test")
        self.write("tools/validation/contracts.json", json.dumps(self.manifest))
        self.commit()
        self.base = self.git("rev-parse", "HEAD").strip()
        self.write("audio/sound.gd", "# changed\n")
        self.assertIn("added_test", self.plan()["selected_tests"])

    def test_removed_test_without_registry_change_is_an_error(self):
        (self.project / "tests/audio_test.gd").unlink()
        with self.assertRaisesRegex(ValueError, "Missing test"): self.plan()

    def test_documentation_plan_and_list_never_launch_engine_or_write_reports(self):
        self.write("docs/notes.md", "new notes\n")
        destination = self.project.parent / "not-created"
        with patch.object(validate_godot, "validation_editor") as engine:
            code, text = self.cli(["--changed-since", self.base, "--plan", "--output", str(destination)])
            self.assertEqual(code, 0)
            self.assertEqual(json.loads(text)["scope"], "documentation")
            code, text = self.cli(["--changed-since", self.base, "--list-tests"])
            self.assertEqual(text.strip(), "")
            engine.assert_not_called()
        self.assertFalse(destination.exists())

    def test_summary_keeps_full_selection_and_source_without_running_checks(self):
        self.write("core/save.gd", "changed writer\n")
        destination = self.project.parent / "not-created"
        plan = self.plan()
        before = copy.deepcopy(plan)
        summary = summarize_plan(plan)
        self.assertEqual(plan, before)
        self.assertIn("Scope: full", summary)
        self.assertIn("Selected tests: 3/3", summary)
        self.assertIn("Main/runtime checks required: yes", summary)
        self.assertIn("shared_infrastructure_requires_full=1", summary)
        self.assertIn(self.base, summary)
        self.assertIn(plan["source"]["head_tree"], summary)
        self.assertIn("no tests executed", summary)
        with patch.object(validate_godot, "validation_editor") as engine, patch.object(validate_godot, "SourceRun") as source:
            code, output = self.cli(["--changed-since", self.base, "--plan", "--summary", "--output", str(destination)])
            self.assertEqual(code, 0)
            self.assertEqual(output.strip(), summary)
            engine.assert_not_called()
            source.assert_not_called()
        self.assertFalse(destination.exists())

    def test_summary_remains_bounded_for_many_files_and_contracts(self):
        plan = self.plan()
        plan["source"]["changes"] = [{"path": f"unknown/{i}.gd"} for i in range(10000)]
        plan["decisions"] = [{"reason": "unmapped_path_requires_full"} for _ in range(10000)]
        plan["contracts"] = [f"contract_{i}" for i in range(200)]
        summary = summarize_plan(plan)
        self.assertIn("Changed paths: 10000", summary)
        self.assertIn("unmapped_path_requires_full=10000", summary)
        self.assertIn("+192 more", summary)
        self.assertLess(len(summary), 1600)

    def test_summary_rejects_execution_and_list_modes(self):
        for flags in [["--summary"], ["--changed-since", self.base, "--summary"],
                      ["--changed-since", self.base, "--plan", "--summary", "--list-tests"]]:
            with self.subTest(flags=flags), patch.object(validate_godot, "validation_editor") as engine:
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                    self.cli(flags)
                self.assertEqual(caught.exception.code, 2)
                engine.assert_not_called()

    def test_invalid_ref_and_conflicting_selectors_stop_before_engine(self):
        for flags in [["--changed-since", "missing-ref"], ["--changed-since", "--help"],
                      ["--changed-since", self.base, "--contracts", "audio"], ["--plan"]]:
            with self.subTest(flags=flags), patch.object(validate_godot, "validation_editor") as engine:
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                    self.cli(flags)
                self.assertEqual(caught.exception.code, 2)
                engine.assert_not_called()

    def test_full_selection_cannot_be_silently_reduced_by_skip_main(self):
        self.write("core/save.gd", "changed writer\n")
        with patch.object(validate_godot, "validation_editor") as engine:
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                self.cli(["--changed-since", self.base, "--skip-main"])
            self.assertEqual(caught.exception.code, 2)
            engine.assert_not_called()

    def test_nonempty_output_is_preserved_before_launch(self):
        self.write("ui/view.gd", "changed\n")
        output = self.project.parent / "previous"
        output.mkdir()
        (output / "results.json").write_text("previous evidence")
        with patch.object(validate_godot, "validation_editor") as engine:
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                self.cli(["--changed-since", self.base, "--output", str(output)])
            engine.assert_not_called()
        self.assertEqual((output / "results.json").read_text(), "previous evidence")

    def test_rules_cannot_reference_unknown_contracts_or_duplicate_test_lists(self):
        for alteration in [{"contracts": ["typo"]}, {"tests": ["audio_test"]}]:
            rules = copy.deepcopy(self.rules)
            rules["rules"][0].update(alteration)
            self.write("tools/validation/selection_rules.json", json.dumps(rules))
            with self.assertRaises(ValueError): self.plan()

    def test_symlink_is_hashed_without_reading_target_and_requires_full(self):
        outside = self.project.parent / "outside.txt"
        outside.write_text("external contents")
        link = self.project / "docs/link.md"
        link.symlink_to(outside)
        plan = self.plan()
        self.assertEqual(plan["scope"], "full")
        self.assertTrue(plan["source"]["changes"][0]["symlink"])

    def test_worktree_and_nested_project_boundaries(self):
        other = self.project.parent / "linked"
        self.git("worktree", "add", "-q", "-b", "test-linked", str(other), self.base)
        (other / "ui/view.gd").write_text("changed in linked worktree\n")
        self.assertEqual(build_plan(other, self.base)["selected_tests"], ["extra_test", "ui_test"])
        with self.assertRaisesRegex(ValueError, "repository root"):
            from validation_plan import changed_paths
            changed_paths(other / "ui", self.base)

    def test_deleted_symlink_still_requires_full(self):
        link = self.project / "docs/link.md"
        link.symlink_to("notes.md")
        self.commit()
        self.base = self.git("rev-parse", "HEAD").strip()
        link.unlink()
        self.assertEqual(self.plan()["scope"], "full")

    def test_unmerged_conflict_stops_planning(self):
        original_branch = self.git("branch", "--show-current").strip()
        self.git("checkout", "-qb", "conflicting")
        self.write("ui/view.gd", "branch value\n")
        self.commit()
        self.git("checkout", "-q", original_branch)
        self.write("ui/view.gd", "other value\n")
        self.commit()
        result = subprocess.run(["git", "-C", str(self.project), "merge", "conflicting"], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        with self.assertRaisesRegex(ValueError, "Resolve Git conflicts"): self.plan()

    def test_real_rules_use_registry_and_expand_audio_consumers(self):
        registry, owners = read_contracts(ROOT)
        rules = read_rules(ROOT, {c["id"] for c in registry["contracts"]})
        plan = select_changes([{"path": "audio/runtime/director.gd", "status": "M"}], registry, owners, rules)
        self.assertEqual(set(plan["contracts"]), {"audio", "wildlife", "spherical_gameplay"})
        self.assertLess(plan["selected_test_count"], plan["registered_test_count"])
        self.assertIn("spherical_gameplay_test", plan["selected_tests"])


if __name__ == "__main__":
    unittest.main()
