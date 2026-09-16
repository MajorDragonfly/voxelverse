"""Exercise misleading progress, stale sources and incomplete GitHub inventories."""
import copy
from decimal import Decimal
import json
from pathlib import Path
import sys
import tempfile
import unittest
from urllib.error import HTTPError
from xml.etree import ElementTree

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import project_dashboard as dashboard


class ProjectDashboardTest(unittest.TestCase):
    def setUp(self):
        self.data = {
            "schema": 1, "repository": "MajorDragonfly/voxelverse", "reviewed_on": "2026-09-16",
            "scope_version": 1, "scope": "Test scope", "coordination_issue": 137,
            "campaign_summary": "Fixture", "remaining_summary": "Open epochs",
            "coordination_note": "Assignments need a coordinator", "target_hardware": "Test PC",
            "target_goal": "Measured target", "acceptance": {"status": "pending", "summary": "Open"},
            "main": {"branch": "main", "sha": "1"*40, "evidence": "https://example.test/main"},
            "candidate": {"branch": "agent/candidate", "sha": "2"*40, "pr": 125, "evidence": "https://example.test/candidate"},
            "areas": [{"id": key, "title": key, "weight": weight, "low": low, "high": high,
                       "achieved": "Foundation", "remaining": "Gameplay", "evidence": "https://example.test/evidence"}
                      for key, weight, low, high in [("first", 40, 20, 40), ("second", 60, 50, 70)]],
            "included": [{"pr": 93, "head": "3"*40}], "alternatives": [122],
            "deliveries": [{"id": key, "title": key, "area": "first", "status": "delivered",
                            "pr": pr, "head": "4"*40, "depends_on": [], "limits": "Limited",
                            "evidence": "https://example.test/delivery"}
                           for key, pr in [("TEST-ONE", 126), ("TEST-TWO", 127)]],
            "priorities": ["First", "Second", "Third"], "blockers": ["Acceptance"],
        }
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / dashboard.DATA).parent.mkdir(parents=True)
        (self.root / "README.md").write_text("Before\n" + dashboard.START + "\n" + dashboard.END + "\nAfter\n")

    def save(self, data):
        (self.root / dashboard.DATA).write_text(json.dumps(data), encoding="utf-8")

    def test_estimate_is_weighted_and_independent_of_delivery_counts(self):
        expected = (Decimal("38"), Decimal("58"), Decimal("48"))
        self.assertEqual(dashboard.score(self.data), expected)
        self.data["deliveries"] = []
        self.data["included"] = []
        self.assertEqual(dashboard.score(self.data), expected)

    def test_rejects_invalid_weights_intervals_and_duplicate_areas(self):
        cases = []
        for key, value in (("weight", 16), ("weight", True), ("low", -1),
                           ("high", 101), ("low", 90), ("low", True)):
            case = copy.deepcopy(self.data)
            case["areas"][0][key] = value
            cases.append(case)
        case = copy.deepcopy(self.data)
        case["areas"][1]["id"] = case["areas"][0]["id"]
        cases.append(case)
        for case in cases:
            with self.subTest(area=case["areas"][0]):
                self.save(case)
                with self.assertRaises(ValueError):
                    dashboard.read_project(self.root)

    def test_publication_is_not_automatically_integration_or_acceptance(self):
        for state in ("integrated", "accepted"):
            data = copy.deepcopy(self.data)
            data["deliveries"][0]["status"] = state
            self.save(data)
            with self.assertRaisesRegex(ValueError, "Integration needs"):
                dashboard.read_project(self.root)
        data["deliveries"][0]["integrated_sha"] = data["candidate"]["sha"]
        self.save(data)
        with self.assertRaisesRegex(ValueError, "acceptance_evidence"):
            dashboard.read_project(self.root)
        data["deliveries"][0].update(acceptance_evidence="build-test.md", accepted_by="Tester", build_id="release-test-1")
        self.save(data)
        dashboard.read_project(self.root)

    def test_missing_evidence_and_duplicate_pr_fail(self):
        for field, value in (("head", "abc"), ("evidence", ""), ("pr", self.data["included"][0]["pr"])):
            data = copy.deepcopy(self.data)
            data["deliveries"][0][field] = value
            self.save(data)
            with self.assertRaises(ValueError):
                    dashboard.read_project(self.root)

    def test_target_acceptance_requires_and_displays_exact_evidence(self):
        self.data["acceptance"]["status"] = "accepted"
        self.save(self.data)
        with self.assertRaisesRegex(ValueError, "acceptance evidence"):
            dashboard.read_project(self.root)
        self.data["acceptance"].update(evidence="https://example.test/test", reviewer="Tester",
                                       build_id="build-1", source_sha="8"*40)
        self.save(self.data)
        data = dashboard.read_project(self.root)
        self.assertIn("8"*40, dashboard.acceptance_line(data))
        self.assertIn("build-1", dashboard.acceptance_line(data))

    def test_missing_and_cyclic_dependencies_fail(self):
        data = copy.deepcopy(self.data)
        data["deliveries"][0]["depends_on"] = ["DOES-NOT-EXIST"]
        self.save(data)
        with self.assertRaisesRegex(ValueError, "Unknown dependency"):
            dashboard.read_project(self.root)
        data["deliveries"][0]["depends_on"] = [data["deliveries"][1]["id"]]
        data["deliveries"][1]["depends_on"] = [data["deliveries"][0]["id"]]
        self.save(data)
        with self.assertRaisesRegex(ValueError, "Dependency cycle"):
            dashboard.read_project(self.root)

    def test_render_is_repeatable_preserves_readme_and_detects_stale_outputs(self):
        dashboard.render(self.root, self.data)
        original = (self.root / "README.md").read_text()
        self.assertTrue(original.startswith("Before\n"))
        self.assertTrue(original.endswith("\nAfter\n"))
        self.assertEqual(dashboard.render(self.root, self.data), [])
        dashboard.render(self.root, self.data, check=True)
        svg = (self.root / "docs/dashboard/progress.svg").read_text()
        ElementTree.fromstring(svg)
        self.assertIn("38–58 %", svg)
        self.assertNotIn("<script", svg)
        changed = copy.deepcopy(self.data)
        changed["areas"][0]["low"] = 19
        with self.assertRaisesRegex(ValueError, "Stale dashboard"):
            dashboard.render(self.root, changed, check=True)
        self.assertEqual((self.root / "README.md").read_text(), original)

    def test_markers_are_not_guessed_or_silently_duplicated(self):
        for original in ("no markers", dashboard.END + dashboard.START,
                         dashboard.START * 2 + dashboard.END, dashboard.START):
            with self.subTest(original=original), self.assertRaises(ValueError):
                dashboard.replace_block(original, "Generated")

    @staticmethod
    def raw_pr(number, branch="feature", base="main", repo="MajorDragonfly/voxelverse"):
        return {"number": number, "title": "Title", "draft": True,
                "head": {"sha": "a" * 40, "ref": branch, "repo": {"full_name": repo}},
                "base": {"ref": base}}

    def fake_api(self, repo, path):
        if path.startswith("branches/"):
            return {"commit": {"sha": self.data["main"]["sha"]}}
        if path.startswith("pulls/"):
            return {"head": {"sha": self.data["candidate"]["sha"]}, "state": "open", "merged": False}
        if path.endswith("&page=1"):
            return [self.raw_pr(n) for n in range(100)]
        return [self.raw_pr(100)]

    def test_live_fetch_reads_all_pages_and_never_modifies_estimates(self):
        before = copy.deepcopy(self.data)
        live = dashboard.fetch_live(self.data, self.fake_api)
        self.assertEqual(len(live["pulls"]), 101)
        self.assertEqual(before, self.data)
        def failure(repo, path):
            raise HTTPError("https://api.github.com", 403, "rate limited", {}, None)
        with self.assertRaises(HTTPError):
            dashboard.fetch_live(self.data, failure)

    def test_live_inventory_rejects_pagination_limit(self):
        def endless(repo, path):
            return [self.raw_pr(n) for n in range(100)]
        with self.assertRaisesRegex(ValueError, "incomplete inventory"):
            dashboard.fetch_live(self.data, endless)

    def test_live_reports_exact_inclusion_and_changed_heads(self):
        live = dashboard.fetch_live(self.data, self.fake_api)
        entry = self.data["included"][0]
        live["pulls"] = [{"number": entry["pr"], "head": entry["head"], "title": "original",
                          "draft": True, "branch": "feature", "base": "main", "head_repo": self.data["repository"]}]
        self.assertIn("Im festen Kandidaten enthalten", dashboard.live_markdown(self.data, live))
        live["pulls"][0]["head"] = "b" * 40
        self.assertIn("Nachlieferung / Kandidatenabgleich nötig", dashboard.live_markdown(self.data, live))
        live["candidate_sha"] = "c" * 40
        self.assertIn("Basis hat sich geändert", dashboard.live_markdown(self.data, live))

    def test_branch_stacks_and_untrusted_titles(self):
        live = dashboard.fetch_live(self.data, self.fake_api)
        live["pulls"] = [
            {"number": 201, "head": "a"*40, "title": "[click](evil) | @person\n<script>x</script>",
             "draft": False, "branch": "parent", "base": "main", "head_repo": self.data["repository"]},
            {"number": 202, "head": "b"*40, "title": "Child", "draft": True,
             "branch": "child", "base": "parent", "head_repo": self.data["repository"]},
        ]
        report = dashboard.live_markdown(self.data, live)
        self.assertIn("[\u0023201](https://github.com/MajorDragonfly/voxelverse/pull/201)", report)
        self.assertIn("\\|", report)
        self.assertNotIn("@person", report)
        self.assertNotIn("<script>", report)
        live["pulls"][0]["head_repo"] = "external/fork"
        report = dashboard.live_markdown(self.data, live)
        self.assertIn("| Entwurf | parent |", report)

    def test_detailed_integrations_are_included_but_deliveries_are_not(self):
        item = self.data["deliveries"][0]
        live = dashboard.fetch_live(self.data, self.fake_api)
        live["pulls"] = [{"number": item["pr"], "head": item["head"], "title": "Detailed",
                          "draft": True, "branch": "detail", "base": "main"}]
        self.assertNotIn("Im festen Kandidaten enthalten", dashboard.live_markdown(self.data, live))
        item.update(status="integrated", integrated_sha=self.data["candidate"]["sha"])
        self.assertIn("Im festen Kandidaten enthalten", dashboard.live_markdown(self.data, live))
        live["pulls"][0]["head"] = "f" * 40
        self.assertIn("Nachlieferung / Kandidatenabgleich nötig", dashboard.live_markdown(self.data, live))

    def test_metadata_followup_requires_verified_ancestry_and_complete_safe_diff(self):
        expected = self.data["candidate"]["sha"]
        comparison = {"status": "ahead", "merge_base_commit": {"sha": expected},
                      "files": [{"filename": "tools/workflow/project.json"},
                                {"filename": "docs/PROJECT_DASHBOARD.md"}]}
        def api(repo, path):
            if path.startswith("compare/"):
                self.assertEqual(path, "compare/" + expected + "..." + "f" * 40)
                return comparison
            result = self.fake_api(repo, path)
            if path.startswith("pulls/"):
                result["head"]["sha"] = "f" * 40
            return result
        before = copy.deepcopy(self.data)
        live = dashboard.fetch_live(self.data, api)
        self.assertTrue(live["candidate_metadata_only"])
        self.assertNotIn("Basis hat sich geändert", dashboard.live_markdown(self.data, live))
        self.assertEqual(self.data, before)
        for files in ([{"filename": "main/spherical_campaign.gd"}],
                      [{"filename": "docs/moved.md", "previous_filename": "main/game.gd"}],
                      [{"filename": "docs/readme.md"}] * 300, [],
                      [{"filename": "docs/../main/game.gd"}]):
            comparison["files"] = files
            self.assertFalse(dashboard.fetch_live(self.data, api)["candidate_metadata_only"])
        comparison["files"] = [{"filename": "README.md"}]
        comparison["status"] = "diverged"
        self.assertFalse(dashboard.fetch_live(self.data, api)["candidate_metadata_only"])
        comparison["status"] = "ahead"
        comparison["merge_base_commit"]["sha"] = "e" * 40
        self.assertFalse(dashboard.fetch_live(self.data, api)["candidate_metadata_only"])

    def test_real_project_data_is_valid(self):
        dashboard.read_project()


if __name__ == "__main__":
    unittest.main()
