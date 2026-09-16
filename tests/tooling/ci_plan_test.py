"""PR merge fixtures ensure draft selection can never replace ready acceptance."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from ci_plan import plan


class CIPlanTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "CI fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.write("tools/validation/contracts.json", json.dumps({"schema": 1, "contracts": [
            {"id": "audio", "title": "Audio", "work": "fixture", "tests": ["audio_test"]},
            {"id": "other", "title": "Other", "work": "fixture", "tests": ["other_test"]}],
            "scenarios": [{"id": "future", "scope": "pending", "limits": "not implemented", "status": "pending", "tests": []}]}))
        self.write("tools/validation/selection_rules.json", json.dumps({"schema": 1,
            "documentation": ["docs/*.md"], "full": ["tools/*"],
            "rules": [{"id": "audio", "paths": ["audio/*"], "contracts": ["audio"]}]}))
        for name in ("audio", "other"):
            self.write(f"tests/{name}_test.gd", "extends SceneTree\n")
        self.write("audio/sound.gd", "# before\n")
        self.write("docs/notes.md", "Before\n")
        self.commit()
        self.base = self.git("rev-parse", "HEAD")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True, stderr=subprocess.PIPE).strip()

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture")

    def event(self, draft):
        return {"pull_request": {"base": {"sha": self.base},
                                 "head": {"sha": self.git("rev-parse", "HEAD")}, "draft": draft}}

    def test_draft_selects_domain_and_ready_requires_every_test(self):
        self.write("audio/sound.gd", "# changed\n")
        self.commit()
        draft = plan(self.root, "pull_request", self.event(True))
        self.assertEqual(draft["selected_tests"], 1)
        self.assertFalse(draft["acceptance"])
        ready = plan(self.root, "pull_request", self.event(False))
        self.assertEqual(ready["mode"], "full")
        self.assertTrue(ready["runtime"] and ready["acceptance"])
        tests = [t for shard in ready["matrix"]["include"] for t in shard["tests"]]
        self.assertEqual(sorted(tests), ["audio_test", "other_test"])

    def test_unknown_draft_path_keeps_full_source_and_runtime(self):
        self.write("unknown/save.gd", "# new infrastructure\n")
        self.commit()
        result = plan(self.root, "pull_request", self.event(True))
        self.assertEqual(result["selected_tests"], 2)
        self.assertTrue(result["runtime"])

    def test_documentation_is_explicitly_exempt_in_ready_pr(self):
        self.write("docs/notes.md", "Changed\n")
        self.commit()
        result = plan(self.root, "pull_request", self.event(False))
        self.assertEqual(result["mode"], "documentation")
        self.assertFalse(result["source"] or result["runtime"] or result["acceptance"])
        self.assertFalse(result["tests_executed"])

    def test_main_and_manual_runs_are_always_full(self):
        for event in ("push", "workflow_dispatch"):
            result = plan(self.root, event, self.event(True))
            self.assertEqual(result["mode"], "full")
            self.assertTrue(result["source"] and result["runtime"] and result["acceptance"])

    def test_missing_base_and_head_only_checkout_fail_closed(self):
        event = self.event(True)
        event["pull_request"]["base"]["sha"] = "f" * 40
        with self.assertRaises(ValueError):
            plan(self.root, "pull_request", event)
        self.git("checkout", "-qb", "base-advanced")
        self.write("docs/notes.md", "new base\n")
        self.commit()
        new_base = self.git("rev-parse", "HEAD")
        self.git("checkout", "-q", self.base)
        event = self.event(False)
        event["pull_request"]["base"]["sha"] = new_base
        with self.assertRaises(ValueError):
            plan(self.root, "pull_request", event)

    def test_each_actual_gate_rejects_failure_cancellation_and_unplanned_skip(self):
        # Execute the actual workflow shell bodies without a YAML dependency.
        for file in ("godot-validate.yml", "export-validate.yml", "render-validate.yml"):
            source = (ROOT / ".github/workflows" / file).read_text()
            gate = source.split("\n  validate:\n", 1)[1]
            script = "\n".join(line[10:] for line in gate.split("        run: |\n", 1)[1].splitlines() if line.startswith("          "))
            if file == "godot-validate.yml":
                env = {"CONTRACTS_RESULT": "success", "SOURCE_RESULT": "success", "RUNTIME_RESULT": "success",
                       "SOURCE_REQUIRED": "true", "RUNTIME_REQUIRED": "true"}
                results = ["CONTRACTS_RESULT", "SOURCE_RESULT", "RUNTIME_RESULT"]
            else:
                env = {"PLAN_RESULT": "success", "REQUIRED": "true", "RESULT": "success"}
                results = ["PLAN_RESULT", "RESULT"]
            self.assertEqual(subprocess.run(["bash", "-e", "-c", script], env=env).returncode, 0)
            for key in results:
                for failure in ("failure", "cancelled", "skipped", ""):
                    with self.subTest(file=file, key=key, failure=failure):
                        self.assertNotEqual(subprocess.run(["bash", "-e", "-c", script], env=env | {key: failure}).returncode, 0)


if __name__ == "__main__":
    unittest.main()
