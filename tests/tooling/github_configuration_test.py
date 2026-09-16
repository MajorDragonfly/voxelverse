"""Protect setup ordering and preserve pre-existing repository rules."""
import copy
import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from configure_github import configure, matches


class GitHubConfigurationTest(unittest.TestCase):
    def setUp(self):
        self.plan = configure()
        self.repo = {"default_branch": "main", "permissions": {"admin": True}, "allow_auto_merge": False}
        self.rule = None
        self.writes = []
        self.checks = [{"name": c["context"], "app": {"id": 15368}} for c in
                       self.plan["ruleset"]["rules"][-1]["parameters"]["required_status_checks"]]

    def api(self, path, method="GET", data=None):
        if method != "GET":
            self.writes.append((method, path))
        if path == "":
            if data: self.repo.update(data)
            return self.repo
        if path.startswith("commits/"): return {"check_runs": self.checks}
        if path.startswith("rulesets?"): return [self.rule] if self.rule else []
        if path == "rulesets" and method == "POST":
            self.rule = copy.deepcopy(data) | {"id": 17}
            return self.rule
        if path == "rulesets/17": return self.rule
        self.fail(path)

    def test_protection_is_installed_before_auto_merge_and_read_back(self):
        result = configure(True, self.api)
        self.assertTrue(result["applied"])
        self.assertEqual(self.writes, [("POST", "rulesets"), ("PATCH", "")])
        self.writes.clear()
        configure(True, self.api)
        self.assertEqual(self.writes, [("PATCH", "")])

    def test_admin_or_missing_gate_failure_cannot_enable_auto_merge(self):
        self.repo["permissions"]["admin"] = False
        with self.assertRaises(ValueError): configure(True, self.api)
        self.repo["permissions"]["admin"] = True
        self.checks.pop()
        with self.assertRaises(ValueError): configure(True, self.api)
        self.assertEqual(self.writes, [])

    def test_existing_different_policy_is_preserved(self):
        self.rule = copy.deepcopy(self.plan["ruleset"]) | {"id": 17}
        self.rule["bypass_actors"] = [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]
        with self.assertRaisesRegex(ValueError, "preserving"):
            configure(True, self.api)
        self.assertEqual(self.writes, [])

    def test_server_defaults_and_rule_order_do_not_break_readback(self):
        rule = copy.deepcopy(self.plan["ruleset"])
        rule["id"] = 17
        rule["rules"].reverse()
        rule["rules"][1]["parameters"]["allowed_merge_methods"] = ["merge", "squash", "rebase"]
        self.assertTrue(matches(rule, self.plan["ruleset"]))
        rule["enforcement"] = "disabled"
        self.assertFalse(matches(rule, self.plan["ruleset"]))


if __name__ == "__main__":
    unittest.main()
