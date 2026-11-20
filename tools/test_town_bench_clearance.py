"""Source-bound horizontal geometry regression, without importing/running Godot.

The full rear support/foot envelope must clear the complete bench footprint,
irrespective of the random stay offset or terrain height. These checks do not
replace a seeded runtime/rendering test. Source assertions fail closed if the
placement rule or model dimensions change instead of silently testing stale math.
"""

import math
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
QUADRANTS = ((-1, -1), (-1, 1), (1, -1), (1, 1))
BENCH_RADIUS = math.hypot(0.95, 0.25)  # entire seat, back and legs, any yaw
DUMP_OFFSET = 7.4
REAR_FENCE = 2.5
STAY_FOOT_REACH = 1.15 + 0.55 / 2  # foot is rotated 90 degrees
FOUNTAIN_HALF = 2.6  # square reservation, not a circular exclusion


def square_loop(source):
    square = source.split("func _square(", 1)[1].split("\nfunc ", 1)[0]
    return square.split("\tfor i in 4:\n", 1)[1].split("\n\t# trees", 1)[0]


def source_dimensions(source):
    loop = square_loop(source)
    radius = float(re.search(r"Vector3\(cos\(a\), 0, sin\(a\)\) \* ([0-9.]+)", loop)[1])
    shift = float(re.search(r"off\.x \+= q\.x \* ([0-9.]+)", loop)[1])
    return radius, shift


def benches(radius, shift, qx, qz, mission=False):
    result = []
    for i in range(4):
        angle = math.pi / 4 + i * math.pi / 2
        x, z = math.cos(angle) * radius, math.sin(angle) * radius
        if not mission and x * qx < 0 and z * qz > 0:
            x += qx * shift
        result.append((x, z))
    return result


class TownBenchClearance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.town = (ROOT / "scripts/game/towngen.gd").read_text()
        cls.radius, cls.shift = source_dimensions(cls.town)

    def test_placement_contract_preserves_order_and_rng(self):
        loop = square_loop(self.town)
        self.assertIn('if String(world.settings.get("mission", "")) == "" and off.x * q.x < 0.0 and off.z * q.z > 0.0:', loop)
        self.assertIn('_d("bench", c + off, Defs.yaw_of(-off))', loop)
        self.assertIn('_d("lamp_deco", c + Vector3(signf(cos(a)) * 8.6, 0, signf(sin(a)) * 8.6))', loop)
        self.assertEqual(loop.count('_d("bench"'), 1)
        self.assertEqual(loop.count('_d("lamp_deco"'), 1)
        self.assertNotRegex(loop, r"\brng\b|\brand\w*\s*\(|\bcontinue\b|\bbreak\b|\breturn\b")
        self.assertLess(loop.index("off.x +="), loop.index('_d("bench"'))

    def test_source_geometry_matches_the_envelope(self):
        fence = (ROOT / "scripts/game/building_fences.gd").read_text()
        decor = (ROOT / "scripts/game/decor.gd").read_text()
        mapgen = (ROOT / "scripts/game/mapgen.gd").read_text()
        self.assertIn('Vector3(fx, h + 0.05, 0.02), Vector3(fx, 0.1, 1.1), 0.018', fence)
        self.assertIn('Vector3(0.55, 0.14, 0.2), Vector3(fx, 0.07, 1.15)', fence)
        self.assertRegex(fence, r'Vector3\(0\.55, 0\.14, 0\.2\).*Vector3\(0, PI \* 0\.5, 0\)')
        self.assertIn('Vector3(-3.3, 0, 2.5), c + b * Vector3(3.3, 0, 2.5), 2.0, panels)', self.town)
        self.assertIn('tg.square + Vector3(-q.x * 7.4, 0, q.z * 2.6)', mapgen)
        self.assertIn('Defs.yaw_of(Vector3(-q.x, 0, 0))', mapgen)
        self.assertIn('_reserve(c, Vector2(2.6, 2.6), 0.0)', self.town)
        for dimensions in ('Vector3(1.9, 0.04, 0.11)', 'Vector3(1.9, 0.1, 0.035)',
                           'Vector3(0.06, 0.45, 0.42)', 'Vector3(0.05, 0.45, 0.05)',
                           'Vector3(0, 0.62 + k * 0.17, 0.22)', 'Vector3(-0.15, 0, 0)'):
            self.assertIn(dimensions, decor)

    def test_four_orientations_clear_stays_feet_and_fountain(self):
        for qx, qz in QUADRANTS:
            with self.subTest(q=(qx, qz)):
                old = benches(self.radius, 0, qx, qz)
                new = benches(self.radius, self.shift, qx, qz)
                moved = [i for i in range(4) if old[i] != new[i]]
                self.assertEqual(len(moved), 1)
                x, z = new[moved[0]]
                # Dump local +z points toward the square, independent of q.z.
                nearest_bench_edge = DUMP_OFFSET + qx * x - BENCH_RADIUS
                furthest_support_edge = REAR_FENCE + STAY_FOOT_REACH
                self.assertGreaterEqual(nearest_bench_edge - furthest_support_edge, 0.2)
                yaw = math.atan2(x, z)
                bench_half_z = 0.95 * abs(math.sin(yaw)) + 0.25 * abs(math.cos(yaw))
                self.assertGreaterEqual(abs(z) - bench_half_z - FOUNTAIN_HALF, 0.35)
                self.assertLess(abs(x) + BENCH_RADIUS, 10.0)
                self.assertLess(abs(z) + BENCH_RADIUS, 10.0)
                # Side-return stays point outward at local x = +/-3.3.
                local_x = abs(z - qz * 2.6)
                self.assertLess(local_x + BENCH_RADIUS, 3.3 - 0.1)

    def test_mission_squares_keep_all_four_benches(self):
        for qx, qz in QUADRANTS:
            with self.subTest(q=(qx, qz)):
                self.assertEqual(benches(self.radius, 0, qx, qz),
                                 benches(self.radius, self.shift, qx, qz, mission=True))

    def test_unfixed_layout_has_a_real_seat_intersection(self):
        # A legal rear-bay offset, not a claim about the photographed RNG draw.
        # Mirror the witness into each square orientation.
        for qx, qz in QUADRANTS:
            with self.subTest(q=(qx, qz)):
                bx, bz = -qx * self.radius / math.sqrt(2), qz * self.radius / math.sqrt(2)
                y = 0.46
                reach = 0.02 + (1.9 - y) / (1.9 - 0.1) * (1.1 - 0.02)
                wx, wz = -qx * (DUMP_OFFSET - REAR_FENCE - reach), qz * 3.1
                yaw = math.atan2(bx, bz)  # the bench faces the square center
                dx, dz = wx - bx, wz - bz
                x = math.cos(yaw) * dx - math.sin(yaw) * dz
                z = math.sin(yaw) * dx + math.cos(yaw) * dz
                self.assertLess(abs(x), 0.95)
                self.assertGreaterEqual(z, -0.205)
                self.assertLessEqual(z, -0.095)
                self.assertGreaterEqual(y, 0.44)
                self.assertLessEqual(y, 0.48)


if __name__ == "__main__":
    unittest.main()
