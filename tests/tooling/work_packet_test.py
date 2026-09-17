"""Prevent stale briefs and unsafe parallel assignments in the bounded work catalog."""
import copy
import json
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import work_packet


class WorkPacketTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name)
        for folder in ["tools/workflow", "tools/validation", "tests", "docs"]:
            (self.project / folder).mkdir(parents=True)
        for filename in ["example.gd", "tests/example_test.gd", "docs/example.md"]:
            (self.project / filename).write_text("example\n")
        registry = {"schema": 1, "contracts": [
            {"id": "example", "title": "Example", "work": "ARCH-01", "tests": ["example_test"]}],
            "scenarios": [{"id": "future", "status": "pending", "tests": [],
                           "scope": "Future", "limits": "Not implemented"}]}
        (self.project / "tools/validation/contracts.json").write_text(json.dumps(registry))
        self.packet = {"id": "ARCH-01-ONE", "title": "Example", "goal": "Goal",
                       "write_groups": ["save"], "files": ["example.gd"],
                       "read": ["docs/example.md"], "contracts": ["example"],
                       "acceptance": "Restart", "limits": "One scope"}

    def save(self, entries):
        (self.project / work_packet.CATALOG).write_text(json.dumps({"schema": 1, "packets": entries}))

    def test_valid_catalog_and_read_only_brief(self):
        self.save([self.packet])
        packets = work_packet.read_packets(self.project)
        rendered = work_packet.brief(packets["ARCH-01-ONE"])
        self.assertIn("--contracts example --list-tests", rendered)
        self.assertNotIn("example_test", rendered)  # Registry remains sole test source.
        self.assertIn("reserviert nichts", rendered)

    def test_invalid_references_and_duplicate_assignments_are_errors(self):
        cases = [("contracts", ["typo"]), ("files", ["missing.gd"]),
                 ("read", ["../outside.md"]), ("write_groups", [])]
        for field, value in cases:
            with self.subTest(field=field):
                packet = copy.deepcopy(self.packet)
                packet[field] = value
                self.save([packet])
                with self.assertRaises(ValueError):
                    work_packet.read_packets(self.project)
        self.save([self.packet, self.packet])
        with self.assertRaisesRegex(ValueError, "Duplicate packet"):
            work_packet.read_packets(self.project)

    def test_checks_all_pairs_and_actual_file_overlap(self):
        packets = {
            "A": {"write_groups": ["terrain"], "files": ["a.gd"]},
            "B": {"write_groups": ["save"], "files": ["shared.gd"]},
            "C": {"write_groups": ["save"], "files": ["c.gd"]},
            "D": {"write_groups": ["other"], "files": ["shared.gd"]},
        }
        found = work_packet.conflicts(packets, ["A", "B", "C", "D"])
        self.assertEqual({(item["left"], item["right"]) for item in found}, {("B", "C"), ("B", "D")})
        self.assertEqual(work_packet.conflicts(packets, ["A", "C", "D"]), [])
        with self.assertRaisesRegex(ValueError, "more than once"):
            work_packet.conflicts(packets, ["A", "A"])
        with self.assertRaisesRegex(ValueError, "Unknown packets"):
            work_packet.conflicts(packets, ["A", "missing"])

    def test_real_catalog_keeps_source_and_contract_links_current(self):
        work_packet.read_packets(work_packet.ROOT)

    def test_start_uses_main_and_rejects_unintegrated_dependencies(self):
        from project_dashboard import read_project
        data = read_project()
        packets = work_packet.read_packets(work_packet.ROOT)
        packet = packets['WEATHER-05-FORECAST-UI']
        # The real dashboard progresses; this failure-path fixture must still
        # begin with an explicitly unfinished prerequisite.
        for item in data['deliveries']:
            if item['id'] == 'WEATHER-03-STORM-PREVIEW': item['status'] = 'planned'
        with self.assertRaisesRegex(ValueError, 'blocked'):
            work_packet.start_brief(packet, data, 'fixture')
        for item in data['deliveries']:
            if item['id'] == 'WEATHER-03-STORM-PREVIEW': item['status'] = 'integrated'
        text = work_packet.start_brief(packet, data, 'fixture')
        self.assertIn(data['main']['sha'], text)
        self.assertNotIn(data['candidate']['sha'], text)

    def test_non_arch_packets_use_the_same_registry_and_brief(self):
        for key in ["M4-SOCIAL-PLAY", "WEATHER-02B", "UI-MENU-REBIND", "PROJECT-DASHBOARD"]:
            packet = copy.deepcopy(self.packet)
            packet["id"] = key
            self.save([packet])
            self.assertIn(key, work_packet.read_packets(self.project))


class HandoffTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.run_git("init", "-b", "main")
        self.run_git("config", "user.name", "Workflow Test")
        self.run_git("config", "user.email", "workflow-test@example.invalid")
        (self.root / "file.txt").write_text("base\n")
        self.run_git("add", ".")
        self.run_git("commit", "-m", "Base")
        self.base = self.run_git("rev-parse", "HEAD")
        self.run_git("checkout", "-b", "agent/example")
        (self.root / "file.txt").write_text("delivery\n")
        self.run_git("add", ".")
        self.run_git("commit", "-m", "Delivery")

    def run_git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True,
                              capture_output=True, text=True).stdout.strip()

    def test_handoff_records_source_without_running_or_claiming_tests(self):
        output = work_packet.handoff(self.root, "M4-EXAMPLE", self.base)
        self.assertIn(self.run_git("rev-parse", "HEAD"), output)
        self.assertIn(self.run_git("rev-parse", "HEAD^{tree}"), output)
        self.assertIn("file.txt", output)
        self.assertIn("keine Spielprüfung ausgeführt", output)
        self.assertEqual(self.run_git("status", "--porcelain"), "")

    def test_uncommitted_or_untracked_changes_cannot_claim_clean_delivery(self):
        (self.root / "untracked.txt").write_text("unpublished")
        with self.assertRaisesRegex(ValueError, "uncommitted/untracked"):
            work_packet.handoff(self.root, "M4-EXAMPLE", self.base)
        (self.root / "untracked.txt").unlink()
        (self.root / "file.txt").write_text("uncommitted")
        with self.assertRaisesRegex(ValueError, "uncommitted/untracked"):
            work_packet.handoff(self.root, "M4-EXAMPLE", self.base)

    def test_main_detached_and_invalid_base_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "full assigned"):
            work_packet.handoff(self.root, "M4-EXAMPLE", "--help")
        self.run_git("checkout", "main")
        with self.assertRaisesRegex(ValueError, "feature branch"):
            work_packet.handoff(self.root, "M4-EXAMPLE", self.base)
        self.run_git("checkout", "--detach")
        with self.assertRaisesRegex(ValueError, "feature branch"):
            work_packet.handoff(self.root, "M4-EXAMPLE", self.base)

    def test_wrong_ancestry_is_not_a_valid_base(self):
        delivery = self.run_git("rev-parse", "HEAD")
        self.run_git("checkout", "main")
        with self.assertRaises(ValueError):
            work_packet.handoff(self.root, "M4-EXAMPLE", delivery)


if __name__ == "__main__":
    unittest.main()
