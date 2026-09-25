# -*- coding: utf-8 -*-
"""fn-fan-control: 风扇控制模块
枚举 PWM 接口、写入占空比、平滑过渡
"""

import os
import logging
import time
from pathlib import Path
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

# 允许用环境变量覆盖 hwmon 根路径（Docker 冒烟测试指向 mock 目录；生产默认不变）
HWMON_BASE = os.environ.get("FAN_HWMON_BASE", "/sys/class/hwmon")


class FanChannel:
    """一个 PWM 风扇通道"""

    def __init__(self, hwmon_name: str, pwm_index: int, sysfs_path: str):
        self.hwmon_name = hwmon_name   # 如 "hwmon3"
        self.pwm_index = pwm_index     # 如 1 (对应 pwm1)
        self.sysfs_path = sysfs_path   # /sys/class/hwmon/hwmon3
        self.pwm_path = os.path.join(sysfs_path, f"pwm{pwm_index}")
        self.enable_path = os.path.join(sysfs_path, f"pwm{pwm_index}_enable")
        self.fan_path = os.path.join(sysfs_path, f"fan{pwm_index}_input")

        # 通道标识和名称
        self.channel_id = f"{hwmon_name}_pwm{pwm_index}"
        self.label = f"{hwmon_name} PWM{pwm_index}"

        # 当前状态
        self.current_pwm: Optional[int] = None
        self.current_rpm: Optional[int] = None

    @property
    def exists(self) -> bool:
        return os.path.exists(self.pwm_path)

    def read_pwm(self) -> Optional[int]:
        try:
            with open(self.pwm_path) as f:
                self.current_pwm = int(f.read().strip())
            return self.current_pwm
        except Exception:
            return None

    def read_rpm(self) -> Optional[int]:
        try:
            with open(self.fan_path) as f:
                self.current_rpm = int(f.read().strip())
            return self.current_rpm
        except Exception:
            return None

    def write_pwm(self, value: int):
        """写入 PWM 占空比 0-255"""
        value = max(0, min(255, value))
        try:
            # 先启用手动模式 (pwm_enable = 1)
            if os.path.exists(self.enable_path):
                try:
                    with open(self.enable_path, "r") as f:
                        current_enable = f.read().strip()
                    if current_enable != "1":
                        with open(self.enable_path, "w") as f:
                            f.write("1")
                        logger.debug("%s: pwm_enable 设为 1 (手动)", self.channel_id)
                except Exception:
                    pass  # 某些驱动只读

            with open(self.pwm_path, "w") as f:
                f.write(str(value))
            self.current_pwm = value
            logger.debug("%s: PWM 写入 %d", self.channel_id, value)
        except PermissionError:
            logger.error("%s: 写 PWM 权限不足（需 root）", self.channel_id)
            raise
        except Exception as e:
            logger.error("%s: PWM 写入失败: %s", self.channel_id, e)
            raise

    def to_dict(self) -> dict:
        return {
            "channel_id": self.channel_id,
            "label": self.label,
            "hwmon": self.hwmon_name,
            "pwm_index": self.pwm_index,
            "pwm_path": self.pwm_path,
            "current_pwm": self.current_pwm,
            "current_rpm": self.current_rpm,
            "exists": self.exists
        }


class FanManager:
    """管理所有 PWM 风扇通道的发现和控制"""

    def __init__(self):
        self.channels: List[FanChannel] = []

    def discover(self):
        """枚举所有可用的 PWM 风扇接口"""
        self.channels.clear()
        if not os.path.isdir(HWMON_BASE):
            logger.warning("hwmon 目录不存在: %s", HWMON_BASE)
            return

        for hwmon_name in sorted(os.listdir(HWMON_BASE)):
            hwmon_path = os.path.join(HWMON_BASE, hwmon_name)

            # 找到该 hwmon 下的所有 pwm 接口
            pwm_indices = set()
            for f in os.listdir(hwmon_path):
                if f.startswith("pwm") and not f.endswith("_"):
                    # pwm1, pwm2, ... (排除 pwm1_enable 等)
                    try:
                        idx = int(f.replace("pwm", ""))
                        pwm_indices.add(idx)
                    except ValueError:
                        continue

            # 验证：有对应的 fan*_input（转速回报）说明这是一个实际的风扇
            for idx in sorted(pwm_indices):
                pwm_path = os.path.join(hwmon_path, f"pwm{idx}")
                fan_path = os.path.join(hwmon_path, f"fan{idx}_input")

                # 只保留有 fan_input 的（有转速回报的）
                if os.path.exists(fan_path) and os.path.exists(pwm_path):
                    channel = FanChannel(hwmon_name, idx, hwmon_path)
                    self.channels.append(channel)
                    logger.info("发现风扇通道: %s (%s)", channel.channel_id, channel.label)

        logger.info("共发现 %d 个 PWM 风扇通道", len(self.channels))

    def get_channel(self, channel_id: str) -> Optional[FanChannel]:
        for ch in self.channels:
            if ch.channel_id == channel_id:
                return ch
        return None

    def read_all(self):
        """读取所有通道的当前状态"""
        for ch in self.channels:
            ch.read_pwm()
            ch.read_rpm()

    def to_dict(self) -> List[dict]:
        return [ch.to_dict() for ch in self.channels]


class SmoothFanController:
    """
    带平滑过渡的风扇控制器
    避免转速突变（防抖），按步进渐进过渡到目标 PWM
    """

    def __init__(self, channel: FanChannel, step_size: int = 5, step_interval: float = 0.1):
        """
        Args:
            channel: 目标风扇通道
            step_size: 每步 PWM 变化量
            step_interval: 每步间隔(秒)
        """
        self.channel = channel
        self.step_size = step_size
        self.step_interval = step_interval
        self._current_target: int = 0

    def set_target(self, target_pwm: int, smooth: bool = True):
        """
        设置目标 PWM 值，带平滑过渡。

        Args:
            target_pwm: 目标 PWM 值 0-255
            smooth: 是否平滑过渡（True=渐进, False=直接写入）
        """
        target_pwm = max(0, min(255, target_pwm))

        if not smooth:
            self.channel.write_pwm(target_pwm)
            self._current_target = target_pwm
            return

        current = self.channel.read_pwm()
        if current is None:
            current = 0

        # 计算需要走的步数
        diff = target_pwm - current
        steps = abs(diff) // self.step_size
        remainder = abs(diff) % self.step_size

        # 平滑过渡
        direction = 1 if diff > 0 else -1
        for i in range(steps):
            new_val = current + direction * self.step_size * (i + 1)
            self.channel.write_pwm(new_val)
            time.sleep(self.step_interval)

        # 处理余数
        if remainder > 0:
            self.channel.write_pwm(target_pwm)

        self._current_target = target_pwm
        logger.debug("%s: 平滑过渡到 PWM=%d", self.channel.channel_id, target_pwm)
