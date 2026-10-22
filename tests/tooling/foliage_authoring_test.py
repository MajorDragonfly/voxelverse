"""Regression for leaf pigment lost behind already filled foliage volumes."""
from pathlib import Path
import contextlib
import io
import json
import random
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/art"))
from build_benchmark import SLOT, Voxels
import build_benchmark as authoring


class FoliageAuthoringTest(unittest.TestCase):
    def test_filled_crown_receives_both_pigments_without_growing_a_shell(self):
        for family in ("foliage", "shrub"):
            with self.subTest(family=family):
                vox = Voxels(.125, 7177)
                center, radii = (0, 2, 0), (1.2, .9, 1.1)
                vox.ellipsoid(center, radii, family + "_base", .065, False)
                # A real branch penetrates the canopy. Painting must preserve it.
                branch = {(0, y, 0): SLOT["bark_base"] for y in range(8, 20)}
                vox.cells.update(branch)
                occupied = set(vox.cells)
                vox.leaf_lobe(random.Random(7177), center, radii, family, detail=False)
                self.assertEqual(occupied, set(vox.cells), "Pigment must not add a canopy shell")
                self.assertTrue(all(vox.cells[p] == slot for p, slot in branch.items()))
                for suffix in ("highlight", "shadow"):
                    cells = [p for p, value in vox.cells.items() if value == SLOT[family + "_" + suffix]]
                    self.assertGreater(len(cells), 50, "Interior leaf pigment was swallowed by base fill")
                upper = [value for p, value in vox.cells.items() if p[1] * vox.step > center[1] + .3]
                lower = [value for p, value in vox.cells.items() if p[1] * vox.step < center[1] - .3]
                self.assertIn(SLOT[family + "_highlight"], upper)
                self.assertIn(SLOT[family + "_shadow"], lower)

    def test_leaf_colour_and_surface_are_reproducible(self):
        results = []
        for _ in range(2):
            vox = Voxels(.125, 7177)
            vox.leaf_lobe(random.Random(7177), (0, 2, 0), (1.2, .9, 1.1))
            results.append(vox.cells)
        self.assertEqual(results[0], results[1])


class GroundcoverAuthoringTest(unittest.TestCase):
    def test_retained_flower_stems_keep_the_same_curves_in_every_lod(self):
        class RecordedVoxels(Voxels):
            def __init__(self, step, seed):
                super().__init__(step, seed)
                self.curves = []

            def path(self, points, radii, slot, rough=0.0):
                self.curves.append(tuple(points))
                super().path(points, radii, slot, rough)

        for variant in range(3):
            curves = []
            seed = 7177 + authoring.FAMILIES.index('flower_cluster_v2') * 917 + variant * 7907
            for tier, step in enumerate([.03125, .0625, .125]):
                vox = RecordedVoxels(step, seed)
                authoring.flowers(vox, random.Random(seed), tier, variant)
                self.assertTrue(vox.cells)
                curves.append(vox.curves)
            self.assertEqual(curves[0], curves[1])
            self.assertEqual(curves[0][:len(curves[2])], curves[2],
                             'Retained flowers moved when switching to Far')

    def test_cli_exports_and_registers_a_fourth_groundcover_variant(self):
        manifest = (authoring.PACK / 'manifest.json').read_text()
        with tempfile.TemporaryDirectory(prefix='groundcover-cli-') as directory:
            root = Path(directory)
            pack = root / 'assets/packs/temperate_forest_v1'
            pack.mkdir(parents=True)
            (pack / 'manifest.json').write_text(manifest)
            with patch.multiple(authoring, ROOT=root, PACK=pack,
                                RUNTIME=pack / 'environment/benchmark_v2',
                                SOURCE=root / 'art/source/blockbench/environment/benchmark_v2'), \
                    patch.object(sys, 'argv', ['build_benchmark.py', '--families',
                                              'flower_cluster_v2', 'grass_tuft_v2', '--variants', '4']), \
                    contextlib.redirect_stdout(io.StringIO()):
                authoring.main()
            entries = {a['asset_id']: a for a in json.loads((pack / 'manifest.json').read_text())['assets']}
            for family in ['flower_cluster_v2', 'grass_tuft_v2']:
                entry = entries[family]
                self.assertEqual({'0', '1', '2', '3'}, set(entry['variant_sources']))
                self.assertEqual({'0', '1', '2', '3'}, set(entry['geometry_variants']))
                self.assertTrue((root / entry['variant_sources']['3']).is_file())
                for path in entry['geometry_variants']['3'].values():
                    self.assertTrue((root / path.removeprefix('res://')).is_file())


if __name__ == "__main__":
    unittest.main()
