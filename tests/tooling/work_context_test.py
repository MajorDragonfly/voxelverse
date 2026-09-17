"""Start context must not turn a stale catalog or missing assignment into permission."""
import copy
from datetime import datetime, timedelta, timezone
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import work_context as context


NOW = datetime(2026, 9, 17, 12, 0, tzinfo=timezone.utc)
HEAD = "a" * 40


def project_data():
    return {"repository": "example/voxelverse", "coordination_issue": 137,
            "main": {"branch": "main", "sha": "b" * 40}, "reviewed_on": "2026-09-16",
            "priorities": ["One"], "deliveries": [
                {"id": "ARCH-ONE", "status": "planned", "depends_on": []},
                {"id": "ARCH-TWO", "status": "planned", "depends_on": ["ARCH-ONE"]}]}


def packet(name, group="terrain", filename=None):
    return {"id": name, "title": name, "goal": "Goal", "acceptance": "Scenario", "limits": "Bounded",
            "files": [filename or name + ".gd"], "read": ["docs/example.md"],
            "contracts": ["example"], "write_groups": [group]}


def pull(number, title="Unrelated", branch="agent/unrelated"):
    return {"number": number, "title": title, "state": "open", "draft": False,
            "head": {"sha": HEAD, "ref": branch}, "base": {"ref": "main"}}


def observation(body="Central coordination; no machine-readable assignments."):
    return {"observed_at": NOW.isoformat(), "main_sha": HEAD,
            "issue": {"url": "https://github.com/example/voxelverse/issues/137",
                      "updated_at": NOW.isoformat(), "body": body,
                      "body_sha256": context.digest(body)}, "pulls": []}


class CandidateTest(unittest.TestCase):
    def setUp(self):
        self.data = project_data()
        self.packets = {name: packet(name) for name in ("ARCH-ONE", "ARCH-TWO", "ARCH-UNKNOWN")}

    def test_only_planned_with_satisfied_dependencies_are_planning_candidates(self):
        rows = context.packet_rows(self.packets, self.data)
        self.assertEqual([r["id"] for r in rows if r["candidate"]], ["ARCH-ONE"])
        self.assertTrue(all(row["assignment"] == "unknown" for row in rows))
        self.assertIn("unintegrated_recorded_dependencies", rows[1]["reasons"])
        self.assertIn("recorded_status:unrecorded", rows[2]["reasons"])
        self.data["deliveries"][0]["status"] = "integrated"
        rows = context.packet_rows(self.packets, self.data)
        self.assertEqual([r["id"] for r in rows if r["candidate"]], ["ARCH-TWO"])

    def test_completed_or_running_work_cannot_be_next_even_when_catalog_remains(self):
        for status in ("active", "delivered", "integrated", "accepted"):
            with self.subTest(status=status):
                self.data["deliveries"][0]["status"] = status
                row = context.packet_rows(self.packets, self.data)[0]
                self.assertFalse(row["candidate"])
                self.assertIn("recorded_status:" + status, row["reasons"])

    def test_same_file_conflicts_even_with_different_groups_and_explicit_exclusions(self):
        self.packets["ARCH-TWO"] = packet("ARCH-TWO", "other", "ARCH-ONE.gd")
        rows = context.packet_rows(self.packets, self.data, busy=["ARCH-TWO"])
        self.assertFalse(rows[0]["candidate"])
        self.assertEqual(rows[0]["conflicts"][0]["files"], ["ARCH-ONE.gd"])
        self.assertEqual(rows[0]["conflicts"][0]["groups"], [])
        self.assertIn("explicitly_busy", rows[1]["reasons"])
        rows = context.packet_rows(self.packets, self.data, exclude=["ARCH-ONE"])
        self.assertIn("explicitly_excluded", rows[0]["reasons"])
        with self.assertRaisesRegex(ValueError, "Unknown"):
            context.packet_rows(self.packets, self.data, busy=["TYPO-ID"])

    def test_exact_pr_references_block_but_no_fuzzy_status_or_missing_assignment_inference(self):
        live = observation()
        live["pulls"] = [{"number": 5, "title": "ARCH-ONE: delivery", "branch": "agent/task"},
                         {"number": 6, "title": "ARCH-TWO-LATER", "branch": "agent/two"}]
        rows = context.packet_rows(self.packets, self.data, live)
        self.assertFalse(rows[0]["candidate"])
        self.assertEqual(rows[0]["recorded_status"], "planned")
        self.assertEqual(rows[0]["open_pr_references"], [5])
        self.assertEqual(rows[1]["open_pr_references"], [])
        live["pulls"][0]["title"] = "Renamed delivery"
        self.data["deliveries"][0]["pr"] = 5
        self.assertEqual(context.packet_rows(self.packets, self.data, live)[0]["open_pr_references"], [5])

    def test_central_issue_exact_mentions_require_review_without_parsing_free_text_status(self):
        for text in ("ARCH-ONE is active", "ARCH-ONE integrated", "ARCH-ONE maybe free"):
            with self.subTest(text=text):
                row = context.packet_rows(self.packets, self.data, observation(text))[0]
                self.assertFalse(row["candidate"])
                self.assertEqual(row["assignment"], "unknown")
                self.assertEqual(row["recorded_status"], "planned")
                self.assertIn("central_issue_exact_reference_requires_review", row["reasons"])


class NetworkTest(unittest.TestCase):
    def api(self, pages):
        self.calls = []

        def get(repo, path):
            self.calls.append(path)
            if path == "branches/main":
                return {"commit": {"sha": HEAD}}
            if path == "issues/137":
                return {"html_url": observation()["issue"]["url"], "updated_at": NOW.isoformat(),
                        "body": "Saved full issue body, never printed by the brief."}
            page = int(path.rsplit("page=", 1)[1])
            return pages[page - 1]
        return get

    def test_fetches_main_issue_and_every_open_page_without_checks_or_historical_prs(self):
        pages = [[pull(n) for n in range(1, 101)], [pull(101)]]
        result = context.fetch_observation(project_data(), self.api(pages), NOW)
        self.assertEqual(len(result["pulls"]), 101)
        self.assertEqual(len(self.calls), 4)
        self.assertEqual(self.calls[:2], ["branches/main", "issues/137"])
        self.assertTrue(all("state=open" in p for p in self.calls[2:]))
        self.assertTrue(self.calls[-1].endswith("page=2"))
        self.assertIn("Saved full", result["issue"]["body"])
        self.assertEqual(result["issue"]["body_sha256"], context.digest(result["issue"]["body"]))

    def test_exact_full_page_needs_empty_followup_page(self):
        result = context.fetch_observation(project_data(), self.api([[pull(n) for n in range(1, 101)], []]), NOW)
        self.assertEqual(len(result["pulls"]), 100)
        self.assertTrue(self.calls[-1].endswith("page=2"))

    def test_bad_duplicate_and_truncated_pages_fail_closed(self):
        cases = [[{}], [[pull(1)] * 100], [[pull(n) for n in range(1, 101)], [pull(1)]]]
        for pages in cases:
            with self.subTest(pages=len(pages)), self.assertRaises(ValueError):
                context.fetch_observation(project_data(), self.api(pages), NOW)
        pages = [[pull(n) for n in range(1, 101)], [pull(n) for n in range(101, 201)]]
        with patch.object(context, "MAX_PAGES", 2), self.assertRaisesRegex(ValueError, "incomplete"):
            context.fetch_observation(project_data(), self.api(pages), NOW)
        pages = [[pull(1, title="A" * 301)]]
        with self.assertRaisesRegex(ValueError, "title"):
            context.fetch_observation(project_data(), self.api(pages), NOW)


class SnapshotTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "start.json"
        self.data, self.local = project_data(), {"head": HEAD}
        context.save_snapshot(self.path, observation(), self.data, self.local, "source-hash", "same-start")

    def read(self, **kwargs):
        return context.read_snapshot(self.path, self.data, self.local, "source-hash", "same-start", **kwargs)

    def test_fresh_snapshot_retains_issue_once_and_never_requires_network(self):
        with patch.object(context.project_dashboard, "api_get", side_effect=AssertionError("network")):
            self.assertEqual(self.read(now=NOW + timedelta(minutes=29)), observation())

    def test_expired_future_and_unzoned_observations_fail_closed(self):
        for now in (NOW + timedelta(seconds=1801), NOW - timedelta(seconds=1)):
            with self.subTest(now=now), self.assertRaisesRegex(ValueError, "expired or future"):
                self.read(now=now)
        saved = json.loads(self.path.read_text())
        saved["observation"]["observed_at"] = "2026-09-17T12:00:00"
        self.path.write_text(json.dumps(saved))
        with self.assertRaisesRegex(ValueError, "timezone"):
            self.read(now=NOW)

    def test_source_head_session_and_repository_are_bound_to_one_start(self):
        original = json.loads(self.path.read_text())
        for key in ("context_id", "repository", "branch", "local_head", "sources_sha256"):
            saved = copy.deepcopy(original)
            saved[key] = "mismatched"
            self.path.write_text(json.dumps(saved))
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "mismatch: " + key):
                self.read(now=NOW)

    def test_malformed_and_tampered_snapshots_are_not_accepted_as_current(self):
        original = json.loads(self.path.read_text())
        for value in ([], {}, {"schema": True}, "broken"):
            self.path.write_text(json.dumps(value))
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.read(now=NOW)
        for edit in (lambda x: x["observation"].update(main_sha="truncated"),
                     lambda x: x["observation"]["issue"].update(body="modified after fetch"),
                     lambda x: x["observation"]["issue"].update(url="https://other.invalid/issues/137"),
                     lambda x: x["observation"].update(pulls={})):
            saved = copy.deepcopy(original)
            edit(saved)
            self.path.write_text(json.dumps(saved))
            with self.assertRaises(ValueError):
                self.read(now=NOW)


class CommandTest(unittest.TestCase):
    def command(self, args):
        out, error = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(error):
            status = context.main(args)
        return status, out.getvalue(), error.getvalue()

    def test_default_is_offline_bounded_and_reports_actual_git_state_without_tests(self):
        with patch.object(context.project_dashboard, "api_get", side_effect=AssertionError("network")):
            code, text, error = self.command(["next", "--json", "--limit", "2"])
        self.assertEqual((code, error), (0, ""))
        result = json.loads(text)
        actual = context.work_packet.git(context.ROOT, "rev-parse", "HEAD")
        self.assertEqual(result["local"]["head"], actual)
        self.assertEqual(result["observation"]["mode"], "offline")
        self.assertEqual(result["recorded"]["freshness"], "not_verified_against_current_main")
        self.assertLessEqual(len(result["packets"]), 2)
        self.assertTrue(all(x["assignment"] == "unknown" for x in result["packets"]))
        self.assertNotIn("brief", result)

    def test_show_includes_existing_brief_but_never_false_no_network_claim(self):
        data = context.project_dashboard.read_project(context.ROOT)
        live = observation("Large issue body secret marker: " + "x" * 50_000)
        live["issue"]["url"] = f"https://github.com/{data['repository']}/issues/{data['coordination_issue']}"
        with patch.object(context, "fetch_observation", return_value=live):
            code, text, error = self.command(["show", "ARCH-19-TARGET-PC", "--live", "--json"])
        self.assertEqual((code, error), (0, ""))
        result = json.loads(text)
        self.assertEqual(result["observation"]["mode"], "live_observation")
        self.assertEqual(result["recorded"]["freshness"], "differs_from_observed_main")
        self.assertIn("--contracts", result["brief"])
        self.assertNotIn("Keine Netzwerkabfrage", result["brief"])
        self.assertNotIn("Large issue body secret marker", text)
        self.assertNotIn("body", result["observation"]["issue"])

    def test_network_failure_is_an_error_not_offline_success(self):
        with patch.object(context, "fetch_observation", side_effect=OSError("unavailable")):
            code, text, error = self.command(["next", "--live"])
        self.assertEqual(code, 2)
        self.assertEqual(text, "")
        self.assertIn("unavailable", error)

    def test_snapshot_is_cached_not_live_and_cannot_be_checked_into_project(self):
        with tempfile.TemporaryDirectory() as directory:
            snapshot = Path(directory) / "context.json"
            data = context.project_dashboard.read_project(context.ROOT)
            live = observation()
            live["observed_at"] = datetime.now(timezone.utc).isoformat()
            live["issue"]["url"] = f"https://github.com/{data['repository']}/issues/{data['coordination_issue']}"
            with patch.object(context, "fetch_observation", return_value=live):
                code, _, error = self.command(["next", "--live", "--save-snapshot", str(snapshot),
                                                "--context-id", "test-start"])
            self.assertEqual((code, error), (0, ""))
            with patch.object(context.project_dashboard, "api_get", side_effect=AssertionError("network")):
                code, text, error = self.command(["next", "--snapshot", str(snapshot), "--context-id", "test-start", "--json"])
            self.assertEqual((code, error), (0, ""))
            self.assertEqual(json.loads(text)["observation"]["mode"], "cached_observation")
            with patch.object(context, "fetch_observation", return_value=live):
                code, _, error = self.command(["next", "--live", "--save-snapshot", str(context.ROOT / "forbidden-snapshot.json"),
                                                "--context-id", "test-start"])
            self.assertEqual(code, 2)
            self.assertIn("outside", error)
            self.assertFalse((context.ROOT / "forbidden-snapshot.json").exists())

    def test_invalid_options_and_stale_snapshot_fail_without_network_or_partial_output(self):
        for args in (["next", "--limit", "0"], ["next", "--save-snapshot", "irrelevant"],
                     ["next", "--snapshot", "irrelevant"], ["show", "UNKNOWN-PACKET"]):
            with self.subTest(args=args), patch.object(context.project_dashboard, "api_get", side_effect=AssertionError("network")):
                code, text, error = self.command(args)
            self.assertEqual(code, 2)
            self.assertEqual(text, "")
            self.assertTrue(error.startswith("WORK_CONTEXT_FAILED:"))


if __name__ == "__main__":
    unittest.main()
