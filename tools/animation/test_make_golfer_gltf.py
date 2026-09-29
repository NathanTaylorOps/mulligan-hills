"""Run: python3 -m unittest tools/animation/test_make_golfer_gltf.py  (or: cd tools/animation && python3 -m unittest)"""
import json, os, sys, tempfile, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_golfer_gltf as m


class GolferGltfTest(unittest.TestCase):
    def test_many_seeds_validate(self):
        d = tempfile.mkdtemp()
        for seed in range(40):
            path, mesh, names, _ = m.write_gltf(d, "g%d" % seed, m.pick_variant(seed))
            self.assertEqual(m.validate(path), [], "seed %d" % seed)
            self.assertTrue(800 <= len(mesh.tris) <= 1500)

    def test_same_seed_same_bytes(self):
        d = tempfile.mkdtemp()
        m.write_gltf(d, "a", m.pick_variant(5))
        m.write_gltf(d, "b", m.pick_variant(5))
        self.assertEqual(open(d + "/a.bin", "rb").read(), open(d + "/b.bin", "rb").read())

    def test_required_bones(self):
        names, _, _ = m.build_skeleton(1.0)
        for b in m.REQUIRED_GODOT_BONES:
            self.assertIn(b, names)

    def test_validator_catches_bad_weights(self):
        d = tempfile.mkdtemp()
        path, *_ = m.write_gltf(d, "x", m.pick_variant(2))
        g = json.load(open(path))
        acc = g["meshes"][0]["primitives"][0]["attributes"]["WEIGHTS_0"]
        off = g["bufferViews"][g["accessors"][acc]["bufferView"]]["byteOffset"]
        b = bytearray(open(d + "/x.bin", "rb").read())
        b[off:off + 8] = b"\x00\x00\x80\x3f\x00\x00\x80\x3f"
        open(d + "/x.bin", "wb").write(bytes(b))
        self.assertTrue(any("weights sum" in e for e in m.validate(path)))


if __name__ == "__main__":
    unittest.main()
