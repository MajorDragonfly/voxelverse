"""PR merge fixtures ensure draft selection can never replace ready acceptance."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from ci_plan import plan, read_timings, source_shards, TIMING_PROFILE, UNKNOWN_TEST_SECONDS


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
        self.timings = {"schema": 1, "source": {
            "commit": "a" * 40, "tree": "b" * 40, "workflow_run_id": 123,
            "runner": "ubuntu-latest", "godot": "4.6.3.stable.fixture",
            "artifacts": [{"path": "measured/source.zip", "sha256": "c" * 64}]},
            "seconds": {"audio_test": 2.0, "other_test": 3.0}}
        self.write(str(TIMING_PROFILE), json.dumps(self.timings))
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

    def shallow_checkout(self, branch, depth):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        checkout = Path(temp.name) / "checkout"
        # file:// exercises real upload-pack/shallow boundaries, unlike a local
        # clone that can silently ignore --depth and reuse all original objects.
        subprocess.run(["git", "clone", "--quiet", "--no-tags", "--depth", str(depth),
                        "--branch", branch, self.root.as_uri(), str(checkout)],
                       check=True, stderr=subprocess.PIPE)
        return checkout

    def merge_event(self):
        self.git("checkout", "-qb", "feature")
        self.write("audio/sound.gd", "# feature\n")
        self.commit()
        head = self.git("rev-parse", "HEAD")
        self.git("checkout", "-qb", "event-base", self.base)
        self.write("docs/notes.md", "Base advanced while feature was open\n")
        self.commit()
        base = self.git("rev-parse", "HEAD")
        self.git("checkout", "-qb", "ci-merge")
        self.git("merge", "--no-ff", "-m", "Actual PR merge", "feature")
        self.git("tag", "unrelated-history", self.base)
        return {"pull_request": {"base": {"sha": base}, "head": {"sha": head}, "draft": True}}

    def test_exact_shallow_pr_merge_retains_base_selection_and_ready_acceptance(self):
        event = self.merge_event()
        checkout = self.shallow_checkout("ci-merge", 2)
        self.assertEqual(subprocess.check_output(
            ["git", "-C", str(checkout), "rev-parse", "--is-shallow-repository"], text=True).strip(), "true")
        self.assertEqual(subprocess.check_output(
            ["git", "-C", str(checkout), "rev-list", "--all", "--count"], text=True).strip(), "3")
        self.assertEqual(subprocess.check_output(
            ["git", "-C", str(checkout), "tag"], text=True).strip(), "")
        draft = plan(checkout, "pull_request", event)
        self.assertEqual(draft["head"], self.git("rev-parse", "HEAD"))
        self.assertEqual(draft["selection"]["source"]["base_commit"], event["pull_request"]["base"]["sha"])
        self.assertEqual(draft["selection"]["source"]["changes"][0]["path"], "audio/sound.gd")
        self.assertEqual(draft["selected_tests"], 1)
        self.assertFalse(draft["acceptance"])
        event["pull_request"]["draft"] = False
        ready = plan(checkout, "pull_request", event)
        self.assertEqual(ready["mode"], "full")
        self.assertEqual(ready["selected_tests"], 2)
        self.assertTrue(ready["source"] and ready["runtime"] and ready["acceptance"])

    def test_depth_one_push_and_manual_keep_full_acceptance(self):
        self.merge_event()
        checkout = self.shallow_checkout("ci-merge", 1)
        self.assertEqual(subprocess.check_output(
            ["git", "-C", str(checkout), "rev-list", "--all", "--count"], text=True).strip(), "1")
        for event_name in ("push", "workflow_dispatch"):
            result = plan(checkout, event_name, {})
            self.assertEqual(result["mode"], "full")
            self.assertEqual(result["selected_tests"], 2)
            self.assertTrue(result["source"] and result["runtime"] and result["acceptance"])

    def test_shallow_missing_event_base_and_head_only_checkout_fail_closed(self):
        event = self.merge_event()
        checkout = self.shallow_checkout("ci-merge", 2)
        event["pull_request"]["base"]["sha"] = "f" * 40
        with self.assertRaises(ValueError):
            plan(checkout, "pull_request", event)
        # The commits may exist locally yet the actual checkout still lacks
        # the base side. Its selected source test must never become a green plan.
        event["pull_request"]["base"]["sha"] = self.git("rev-parse", "event-base")
        checkout = self.shallow_checkout("feature", 2)
        with self.assertRaises(ValueError):
            plan(checkout, "pull_request", event)
        checkout = self.shallow_checkout("ci-merge", 1)
        with self.assertRaises(ValueError):
            plan(checkout, "pull_request", event)

    def test_actual_plan_workflows_keep_only_required_pr_ancestry(self):
        for name in ("godot-validate.yml", "export-validate.yml", "render-validate.yml"):
            source = (ROOT / ".github/workflows" / name).read_text()
            checkout = source.split("      - uses: actions/checkout@v4\n", 1)[1].split("      - uses:", 1)[0]
            self.assertIn("fetch-depth: ${{ github.event_name == 'pull_request' && 2 || 1 }}", checkout)
            self.assertIn("fetch-tags: false", checkout)
            self.assertIn("persist-credentials: false", checkout)
            self.assertIn("timeout-minutes: 3", source.split("    steps:\n", 1)[0])

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

    def test_balanced_schedule_preserves_every_test_once_and_is_deterministic(self):
        timings = {f"test_{i}_test": float(i + 1) for i in range(23)}
        selected = list(timings)
        shards, loads = source_shards(selected, timings)
        actual = [name for shard in shards for name in shard["tests"]]
        self.assertEqual(sorted(actual), sorted(selected))
        self.assertEqual(len(actual), len(set(actual)))
        self.assertEqual(len(shards), 8)
        self.assertTrue(all(shard["tests"] for shard in shards))
        self.assertEqual((shards, loads), source_shards(list(reversed(selected)), timings))
        self.assertAlmostEqual(sum(loads), sum(timings.values()))
        with self.assertRaisesRegex(ValueError, "duplicates"):
            source_shards(selected + selected[:1], timings)

    def test_measured_long_checks_no_longer_share_an_alphabetical_shard(self):
        selected = [f"test_{i:02}_test" for i in range(12)]
        timings = {name: (600.0 if i % 4 == 0 else 10.0) for i, name in enumerate(selected)}
        _, loads = source_shards(selected, timings)
        old = [sum(timings[name] for name in selected[i::4]) for i in range(4)]
        self.assertLess(max(loads), max(old) / 2)

    def test_new_tests_keep_a_conservative_weight_and_small_selections_have_no_empty_jobs(self):
        shards, loads = source_shards(["new_test", "audio_test"], {"audio_test": 2.0})
        self.assertEqual(len(shards), 2)
        self.assertEqual(shards[0]["tests"], ["new_test"])
        self.assertEqual(loads, [UNKNOWN_TEST_SECONDS, 2.0])
        self.assertEqual(source_shards([], {}), ([], []))

    def test_bad_timing_configuration_never_becomes_a_green_plan(self):
        for value in (0, -1, True, float("nan"), float("inf"), "3", 86401):
            with self.subTest(value=value):
                data = dict(self.timings, seconds={"audio_test": value})
                self.write(str(TIMING_PROFILE), json.dumps(data))
                with self.assertRaisesRegex(ValueError, "source timing profile"):
                    plan(self.root, "workflow_dispatch", {})
        self.write(str(TIMING_PROFILE), json.dumps(dict(self.timings, source={})))
        with self.assertRaises(ValueError):
            read_timings(self.root)
        self.write(str(TIMING_PROFILE), '{"schema":1,"schema":1}')
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            read_timings(self.root)
        (self.root / TIMING_PROFILE).unlink()
        with self.assertRaises(ValueError):
            read_timings(self.root)

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
