"""Protect the existing export installer when the editor-only fast path is used."""
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import install_godot


class InstallerTest(unittest.TestCase):
    def install(self, platform, editor_only):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / "editor.zip"
            names = (["Godot_v4.6.3-stable_win64.exe", "Godot_v4.6.3-stable_win64_console.exe"]
                     if platform == "windows" else ["Godot_v4.6.3-stable_linux.x86_64"])
            with zipfile.ZipFile(archive, "w") as bundle:
                for name in names:
                    bundle.writestr(name, b"fixture editor")
            templates = root / "templates.tpz"
            exports = ["linux_debug.x86_64", "linux_release.x86_64", "windows_debug_x86_64.exe", "windows_release_x86_64.exe"]
            with zipfile.ZipFile(templates, "w") as bundle:
                for name in exports:
                    bundle.writestr("templates/" + name, b"fixture template")
            output = root / "installed"
            output.mkdir()
            sentinel = output / "toolchain.json"
            sentinel.write_text('"previous export installation"')
            downloads = []

            def download(directory, asset):
                downloads.append(asset)
                if editor_only and asset == install_godot.ASSETS["templates"]:
                    self.fail("Editor-only installation requested the large template download")
                return templates if asset == install_godot.ASSETS["templates"] else archive

            args = ["install_godot", "--platform", platform, "--directory", str(output)]
            if editor_only:
                args.append("--editor-only")
            with patch.object(sys, "argv", args), patch.object(install_godot, "download_verified", side_effect=download), contextlib.redirect_stdout(io.StringIO()):
                install_godot.main()
            metadata = json.loads((output / ("editor-toolchain.json" if editor_only else "toolchain.json")).read_text())
            self.assertTrue(Path(metadata["editor"]).is_file())
            if editor_only:
                self.assertEqual(downloads, [install_godot.ASSETS[platform]])
                self.assertIsNone(metadata["templates"])
                self.assertEqual(sentinel.read_text(), '"previous export installation"')
                self.assertFalse((output / "editor/editor_data/export_templates").exists())
            else:
                self.assertEqual(len(downloads), 2)
                self.assertEqual(sorted(p.name for p in Path(metadata["templates"]).iterdir()), sorted(exports))

    def test_linux_editor_only_does_not_download_templates(self):
        self.install("linux", True)

    def test_windows_editor_only_keeps_console_and_gui(self):
        self.install("windows", True)

    def test_default_still_installs_all_export_templates(self):
        self.install("linux", False)


if __name__ == "__main__":
    unittest.main()
