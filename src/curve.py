# -*- coding: utf-8 -*-
"""fn-fan-control: 曲线插值模块
将温度值映射到 PWM 占空比（0-255），
支持多段线性曲线定义。
"""

from dataclasses import dataclass
from typing import List, Tuple


@dataclass
class CurvePoint:
    """曲线上的一个点：温度(℃) → PWM(0-255)"""
    temp: float
    pwm: int


class FanCurve:
    """风扇曲线：多段线性插值，将温度映射到 PWM 值"""

    def __init__(self, points: List[Tuple[float, int]]):
        """
        Args:
            points: [(temp_c, pwm_value), ...] 温度升序排列
                    例: [(30, 40), (40, 80), (50, 150), (60, 255)]
        """
        self._points = sorted([CurvePoint(t, p) for t, p in points], key=lambda x: x.temp)

    @property
    def points(self) -> List[Tuple[float, int]]:
        return [(p.temp, p.pwm) for p in self._points]

    def evaluate(self, temp: float) -> int:
        """
        根据温度计算 PWM 值（线性插值）。

        规则：
        - 低于最低温度点 → 返回最低点的 PWM
        - 高于最高温度点 → 返回最高点的 PWM
        - 在两点之间 → 线性插值

        Args:
            temp: 当前温度 (℃)

        Returns:
            PWM 值 (0-255)
        """
        if not self._points:
            return 128  # 默认中速

        # 低于最低点
        if temp <= self._points[0].temp:
            return self._points[0].pwm

        # 高于最高点
        if temp >= self._points[-1].temp:
            return self._points[-1].pwm

        # 在两点之间：线性插值
        for i in range(len(self._points) - 1):
            lo = self._points[i]
            hi = self._points[i + 1]
            if lo.temp <= temp <= hi.temp:
                span = hi.temp - lo.temp
                if span <= 0:
                    return lo.pwm
                ratio = (temp - lo.temp) / span
                pwm = int(lo.pwm + ratio * (hi.pwm - lo.pwm))
                return max(0, min(255, pwm))

        return self._points[-1].pwm  # 不会到达，保险返回

    def to_dict(self) -> list:
        """序列化为 JSON 可存储的格式"""
        return [{"temp": p.temp, "pwm": p.pwm} for p in self._points]

    @classmethod
    def from_dict(cls, data: list) -> "FanCurve":
        """从 JSON 数据反序列化"""
        points = [(d["temp"], d["pwm"]) for d in data]
        return cls(points)

    def __repr__(self) -> str:
        pts = " → ".join(f"{p.temp}℃:{p.pwm}" for p in self._points)
        return f"FanCurve({pts})"


# 预设曲线
PRESETS = {
    "silent": FanCurve([(30, 40), (40, 70), (50, 120), (60, 200), (70, 255)]),
    "balanced": FanCurve([(30, 60), (40, 100), (50, 160), (60, 220), (70, 255)]),
    "performance": FanCurve([(30, 100), (40, 150), (50, 200), (60, 255)]),
    "full_speed": FanCurve([(0, 255)]),
}
