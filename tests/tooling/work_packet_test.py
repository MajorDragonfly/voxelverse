"""Prevent stale briefs and unsafe parallel assignments in the bounded work catalog."""
import copy
import json
from pathlib import Path
import sys
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


if __name__ == "__main__":
    unittest.main()
