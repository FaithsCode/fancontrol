# -*- coding: utf-8 -*-
"""fn-fan-control: 单元测试
运行: python -m pytest tests/ -v
或在无 pytest 时: python tests/run_tests.py
"""

import sys
import os
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from curve import FanCurve, PRESETS
from config import ConfigManager, _default_config, _default_fan_config


class TestFanCurve(unittest.TestCase):
    """曲线插值测试"""

    def setUp(self):
        self.curve = FanCurve([(30, 50), (40, 100), (50, 200), (60, 255)])

    def test_below_min(self):
        self.assertEqual(self.curve.evaluate(20), 50)

    def test_at_min(self):
        self.assertEqual(self.curve.evaluate(30), 50)

    def test_midpoint(self):
        # 40℃ 在 (30,50) 和 (40,100) 之间 → 应为 100
        self.assertEqual(self.curve.evaluate(40), 100)

    def test_interpolation(self):
        # 35℃ 在 (30,50) 和 (40,100) 之间 → 线性插值 = 75
        self.assertEqual(self.curve.evaluate(35), 75)

    def test_above_max(self):
        self.assertEqual(self.curve.evaluate(70), 255)

    def test_empty_curve(self):
        c = FanCurve([])
        self.assertEqual(c.evaluate(40), 128)  # 默认中速

    def test_single_point(self):
        c = FanCurve([(40, 128)])
        self.assertEqual(c.evaluate(20), 128)
        self.assertEqual(c.evaluate(60), 128)

    def test_serialization(self):
        """序列化→反序列化 应还原一致"""
        original = FanCurve([(25, 30), (45, 120), (65, 255)])
        data = original.to_dict()
        restored = FanCurve.from_dict(data)
        self.assertEqual(original.points, restored.points)

    def test_preset_silent(self):
        self.assertIsInstance(PRESETS["silent"], FanCurve)

    def test_pwm_bounds(self):
        """PWM 值应在 0-255 范围内"""
        for temp in range(0, 100, 5):
            pwm = self.curve.evaluate(temp)
            self.assertGreaterEqual(pwm, 0)
            self.assertLessEqual(pwm, 255)


class TestConfig(unittest.TestCase):
    """配置管理测试"""

    def test_default_config(self):
        cfg = _default_config()
        self.assertIn("interval", cfg)
        self.assertIn("smooth", cfg)
        self.assertIn("fans", cfg)

    def test_default_fan_config(self):
        cfg = _default_fan_config("hwmon3_pwm1", "hwmon3 PWM1")
        self.assertEqual(cfg["mode"], "auto")
        self.assertIn("curve", cfg)
        self.assertIn("min_pwm", cfg)
        self.assertIn("safety_pwm", cfg)

    def test_config_file_roundtrip(self):
        """保存→加载 应还原一致"""
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False, mode="w") as f:
            test_file = f.name

        try:
            mgr1 = ConfigManager(test_file)
            mgr1.config["interval"] = 10
            mgr1.config["fans"]["test_pwm1"] = _default_fan_config("test_pwm1", "Test")
            mgr1.save()

            mgr2 = ConfigManager(test_file)
            cfg2 = mgr2.load()
            self.assertEqual(cfg2["interval"], 10)
            self.assertIn("test_pwm1", cfg2["fans"])
        finally:
            os.unlink(test_file)


if __name__ == "__main__":
    # 无 pytest 时用 unittest 运行
    unittest.main()
