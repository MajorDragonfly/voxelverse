"""Physical corner fixtures and actual exported bytes for baked voxel occlusion."""
import itertools
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/art'))
from build_benchmark import Voxels, greedy_faces, vertex_occlusion, write_bbmodel, write_glb
from export_benchmark_source import export, read_source

TOP = [([0, 1, 0], [1, 1, 0], [1, 1, 1], [0, 1, 1]), [0, 1, 0], 0]


def glb(path):
    data = path.read_bytes()
    size = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20 + size])
    return doc, data[28 + size:]


def payload(doc, binary, index):
    a = doc['accessors'][index]
    view = doc['bufferViews'][a['bufferView']]
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    components = {'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'SCALAR': 1}[a['type']]
    size = a['count'] * components * {5121: 1, 5125: 4, 5126: 4}[a['componentType']]
    return binary[start:start + size]


class VoxelOcclusionTest(unittest.TestCase):
    def fixture(self, cells, step=1.0):
        v = Voxels(step, 0)
        v.cells = {tuple(c): 0 for c in cells}
        v.baked_occlusion = True
        return v

    def test_isolated_cube_has_no_self_occlusion(self):
        vox = self.fixture([(0, 0, 0)])
        colors = vertex_occlusion(vox, greedy_faces(vox))
        self.assertEqual(24 * 4, len(colors))
        self.assertEqual({255}, set(colors))

    def test_open_face_ignores_solid_cells_behind_it(self):
        vox = self.fixture([(0, 0, 0), (-1, 0, 0), (0, 0, -1), (-1, 0, -1)])
        self.assertEqual([255] * 16, vertex_occlusion(vox, [TOP]))

    def test_one_side_or_diagonal_occludes_only_its_nearby_corners(self):
        for cell in [(-1, 1, 0), (-1, 1, -1)]:
            colors = vertex_occlusion(self.fixture([(0, 0, 0), cell]), [TOP])
            self.assertEqual(219, colors[3])
            self.assertEqual(255, colors[11])
            self.assertEqual([255, 255, 255], colors[:3])

    def test_two_walls_close_the_corner_with_or_without_the_diagonal(self):
        for diagonal in [[], [(-1, 1, -1)]]:
            vox = self.fixture([(0, 0, 0), (-1, 1, 0), (0, 1, -1)] + diagonal)
            colors = vertex_occlusion(vox, [TOP])
            self.assertEqual(147, colors[3])
            self.assertEqual(255, colors[11])

    def test_greedy_merge_keeps_a_crease_in_the_middle_of_a_long_face(self):
        vox = self.fixture([(x, 0, 0) for x in range(4)] + [(1, 1, -1)])
        faces = greedy_faces(vox)
        top = [face for face in faces if face[1] == [0, 1, 0] and face[0][0][1] == 1]
        samples = {}
        for face in top:
            colors = vertex_occlusion(vox, [face])[3::4]
            for point, value in zip(face[0], colors):
                samples.setdefault(tuple(point), set()).add(value)
        self.assertEqual({219}, samples[(1.0, 1.0, 0.0)])
        self.assertEqual({219}, samples[(2.0, 1.0, 0.0)])
        self.assertEqual({255}, samples[(0.0, 1.0, 0.0)])
        self.assertEqual({255}, samples[(4.0, 1.0, 0.0)])
        # Flat, unobstructed runs still merge; topology changes are local.
        plain = self.fixture([(x, 0, 0) for x in range(4)])
        self.assertEqual(1, len([f for f in greedy_faces(plain) if f[1] == [0, 1, 0]]))

    def test_straight_occluded_edge_still_merges_along_its_constant_axis(self):
        vox = self.fixture([(x, 0, 0) for x in range(4)] + [(x, 1, -1) for x in range(-1, 5)])
        top = [f for f in greedy_faces(vox) if f[1] == [0, 1, 0] and f[0][0][1] == 1]
        self.assertEqual(1, len(top))
        self.assertEqual({183, 255}, set(vertex_occlusion(vox, top)[3::4]))

    def test_occlusion_survives_all_face_directions_negative_origins_and_grid_sizes(self):
        rotations = [lambda x, y, z: (x, y, z), lambda x, y, z: (x, -y, z),
                     lambda x, y, z: (y, x, z), lambda x, y, z: (-y, x, z),
                     lambda x, y, z: (x, z, y), lambda x, y, z: (x, z, -y)]
        cells = [(0, 0, 0), (-1, 1, 0), (0, 1, -1)]
        expected = vertex_occlusion(self.fixture(cells), [TOP])
        for rotate, step in itertools.product(rotations, [.125, .25, 1.0]):
            shift = (-13, 7, -5)
            transformed = []
            for cell in cells:
                corners = [rotate(*(cell[i] + delta[i] for i in range(3)))
                           for delta in itertools.product([0, 1], repeat=3)]
                transformed.append(tuple(min(p[i] for p in corners) + shift[i] for i in range(3)))
            quad = [[(p[i] + shift[i]) * step for i in range(3)] for p in map(lambda p: rotate(*p), TOP[0])]
            self.assertEqual(expected, vertex_occlusion(self.fixture(transformed, step), [(quad, rotate(*TOP[1]), 0)]))

    def test_export_adds_only_normalized_opaque_alpha_without_changing_geometry(self):
        vox = self.fixture([(0, 0, 0), (-1, 1, 0), (0, 1, -1)])
        faces = greedy_faces(vox)
        with tempfile.TemporaryDirectory() as folder:
            plain, baked = Path(folder) / 'plain.glb', Path(folder) / 'baked.glb'
            a = write_glb(plain, faces, 'fixture')
            b = write_glb(baked, faces, 'fixture', voxels=vox)
            old, old_bin = glb(plain)
            new, new_bin = glb(baked)
            p, q = old['meshes'][0]['primitives'][0], new['meshes'][0]['primitives'][0]
            self.assertNotIn('COLOR_0', p['attributes'])
            for semantic in ['POSITION', 'NORMAL', 'TEXCOORD_0']:
                self.assertEqual(payload(old, old_bin, p['attributes'][semantic]), payload(new, new_bin, q['attributes'][semantic]))
            self.assertEqual(payload(old, old_bin, p['indices']), payload(new, new_bin, q['indices']))
            self.assertEqual(a['triangles'], b['triangles'])
            self.assertEqual(a['vertices'], b['vertices'])
            self.assertEqual('OPAQUE', new['materials'][0]['alphaMode'])
            accessor = new['accessors'][q['attributes']['COLOR_0']]
            self.assertTrue(accessor['normalized'])
            self.assertEqual(5121, accessor['componentType'])
            colors = payload(new, new_bin, q['attributes']['COLOR_0'])
            self.assertTrue(all(colors[i] == 255 for i in range(len(colors)) if i % 4 != 3))
            self.assertLess(min(colors[3::4]), 255)

    def test_editable_source_rebuilds_identical_baked_mesh_and_legacy_stays_opt_in(self):
        with tempfile.TemporaryDirectory() as folder:
            for enabled in [False, True]:
                vox = self.fixture([(0, 0, 0), (-1, 1, 0)])
                vox.baked_occlusion = enabled
                source, built, replay = [Path(folder) / n for n in ['fixture.bbmodel', 'built.glb', 'replay.glb']]
                write_bbmodel(source, vox, 'fixture')
                write_glb(built, greedy_faces(vox), 'fixture', voxels=vox)
                export(source, replay, 'fixture')
                self.assertEqual(built.read_bytes(), replay.read_bytes())
                self.assertEqual(enabled, 'COLOR_0' in glb(replay)[0]['meshes'][0]['primitives'][0]['attributes'])
            doc = json.loads(source.read_text())
            doc['voxelverse']['ambient_occlusion'] = 'unsupported'
            source.write_text(json.dumps(doc))
            with self.assertRaisesRegex(ValueError, 'unsupported ambient occlusion'):
                read_source(source)


if __name__ == '__main__':
    unittest.main()
