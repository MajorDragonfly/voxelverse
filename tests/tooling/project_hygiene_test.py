"""Check failures that would recreate removed files or break a fresh checkout."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import check_project_hygiene as hygiene


class ProjectHygieneTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.project = Path(temporary.name)
        subprocess.run(["git", "init", "-q", str(self.project)], check=True)
        for directory in hygiene.IGNORED_TREES:
            self.write(f"{directory}/.gdignore", "")
        self.write("export_presets.cfg", '[preset.0]\nexclude_filter="' +
                   ",".join(f"{directory}/*" for directory in hygiene.DEV_DIRS) + '"\n')

    def write(self, name, text):
        path = self.project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def test_clean_source_accepts_real_metadata_and_historical_reports(self):
        self.write("runtime.gd", "extends Node\n")
        self.write("runtime.gd.uid", "uid://example\n")
        self.write("docs/evidence/previous-run.log", "historical evidence\n")
        self.assertEqual(hygiene.check(self.project), [])

    def test_deleted_source_leaves_an_error_even_if_git_still_tracks_it(self):
        for name in ["runtime.gd", "runtime.gd.uid", "texture.png", "texture.png.import"]:
            self.write(name, "fixture")
        subprocess.run(["git", "-C", str(self.project), "add", "."], check=True)
        (self.project / "runtime.gd").unlink()
        (self.project / "texture.png").unlink()
        errors = hygiene.check(self.project)
        self.assertEqual(sum("Orphan metadata" in error for error in errors), 2)

    def test_ignored_untracked_source_does_not_hide_an_orphan(self):
        self.write(".gitignore", "ignored.gd\n.godot/\n")
        self.write("ignored.gd", "extends Node\n")
        self.write("ignored.gd.uid", "uid://example\n")
        self.write(".godot/cache", "local cache")
        self.assertEqual(hygiene.check(self.project), ["Orphan metadata without source: ignored.gd.uid"])

    def test_force_added_cache_is_rejected(self):
        self.write(".gitignore", ".godot/\n")
        self.write(".godot/cache", "cache")
        subprocess.run(["git", "-C", str(self.project), "add", "-f", ".godot/cache"], check=True)
        self.assertTrue(any("Generated cache" in error for error in hygiene.check(self.project)))

    def test_extraction_setting_and_generated_palette_are_rejected(self):
        base = hygiene.BENCHMARK + "tree"
        self.write(base + ".glb", "model fixture")
        self.write(base + ".glb.import", "[params]\ngltf/embedded_image_handling=1\n")
        self.write(base + "_0.png", "palette fixture")
        self.write(base + "_0.png.import", "generator_parameters={}\n")
        errors = hygiene.check(self.project)
        self.assertTrue(any("mode 3" in error for error in errors))
        self.assertTrue(any("palette duplicate" in error for error in errors))
        self.write(base + ".glb.import", "[params]\ngltf/embedded_image_handling=3\n")
        for suffix in ["_0.png", "_0.png.import"]:
            (self.project / (base + suffix)).unlink()
        self.assertEqual(hygiene.check(self.project), [])

    def test_every_export_and_import_boundary_is_checked(self):
        with (self.project / "export_presets.cfg").open("a") as output:
            output.write('[preset.1]\nexclude_filter="docs/*"\n')
        (self.project / "evidence/.gdignore").unlink()
        errors = hygiene.check(self.project)
        self.assertTrue(any("Missing import boundary: evidence" in error for error in errors))
        self.assertTrue(any("preset.1 can package development resources: validation" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
