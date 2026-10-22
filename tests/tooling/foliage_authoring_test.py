"""Regression for leaf pigment lost behind already filled foliage volumes."""
from pathlib import Path
import random
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/art"))
from build_benchmark import SLOT, Voxels


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


if __name__ == "__main__":
    unittest.main()
