"""Regression checks for capture statistics and shader option preprocessing."""
from pathlib import Path
import math
import tempfile
import unittest
import zipfile

from benchmark import read_capture, summarize
from validate import SHADERS, expand, profile_options
from package import package


class BenchmarkTests(unittest.TestCase):
    def test_fps_uses_elapsed_time_not_average_instantaneous_fps(self):
        result = summarize([10.0] * 99 + [100.0])
        self.assertAlmostEqual(result["average_fps"], 100000.0 / 1090.0)
        self.assertEqual(result["one_percent_low_fps"], 10.0)

    def test_slowest_percent_uses_mean_frame_time(self):
        result = summarize([10.0] * 198 + [50.0, 150.0])
        self.assertEqual(result["one_percent_low_fps"], 10.0)

    def test_invalid_or_insufficient_data_is_rejected(self):
        for times in ([10.0] * 99, [0.0] * 100, [math.nan] * 100, [math.inf] * 100, [-1.0] * 100):
            with self.assertRaises(ValueError):
                summarize(times)

    def test_semicolon_capture_and_missing_column(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "capture.csv"
            path.write_text("frame;ms\n1;12.5\n2;20\n", encoding="utf-8-sig")
            self.assertEqual(read_capture(path, "ms"), [12.5, 20.0])
            with self.assertRaises(ValueError):
                read_capture(path, "unknown")


class ShaderPreprocessingTests(unittest.TestCase):
    def test_boolean_override_preserves_following_options(self):
        source = expand(SHADERS / "world0/composite3.fsh", profile_options("DREAM"))
        self.assertIn("#define AERO_MOON_PHASES\n", source)
        self.assertIn("#define AERO_STYLE 0", source)
        self.assertIn("#define BLUE_HOUR_STRENGTH 1.00\n", source)
        self.assertIn("#define AURORA_STRENGTH 0.40\n", source)
        self.assertIn("#define PUDDLE_QUALITY 2\n", source)

    def test_disabled_option_stays_disabled_across_nested_includes(self):
        source = expand(SHADERS / "world0/gbuffers_terrain.fsh", {"AERO_WIND": "off"})
        self.assertNotIn("#define AERO_WIND", source)

    def test_dimension_entrypoints_keep_explicit_dimension(self):
        for folder, dimension in (("world0", 0), ("world-1", -1), ("world1", 1)):
            source = expand(SHADERS / folder / "composite3.fsh", {})
            self.assertTrue(source.startswith(f"#version 330 compatibility\n#define AERO_DIMENSION {dimension}\n"))


class PackageTests(unittest.TestCase):
    def test_zip_contains_all_shader_dependencies_and_exact_case_readme(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "AeroDream-test.zip"
            package(path)
            with zipfile.ZipFile(path) as archive:
                names = set(archive.namelist())
                self.assertIn("README.md", names)
                self.assertIn("docs/showcase.html", names)
                self.assertFalse(any(name.startswith(("tools/", ".git/", "dist/")) for name in names))
                import re
                for name in names:
                    if name.startswith("shaders/") and name.endswith((".glsl", ".fsh", ".vsh")):
                        for include in re.findall(r'#include\s+"([^"]+)"', archive.read(name).decode("utf-8")):
                            target = "shaders/" + include.lstrip("/") if include.startswith("/") else str(Path(name).parent / include).replace("\\", "/")
                            self.assertIn(target, names, f"Missing packaged dependency of {name}")


if __name__ == "__main__":
    unittest.main()
