# -*- coding: utf-8 -*-
"""fn-fan-control: 配置管理模块
JSON 配置读写，存放在 /vol2 数据盘（OTA 安全）
"""

import json
import os
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# OTA 安全路径（数据盘，OTA 不会清除）
DEFAULT_CONFIG_DIR = "/vol2/fan-control"
DEFAULT_CONFIG_FILE = os.path.join(DEFAULT_CONFIG_DIR, "config.json")


def _default_config() -> dict:
    """生成默认配置"""
    return {
        "interval": 5,                # 轮询间隔（秒）
        "smooth": True,               # 是否平滑过渡
        "step_size": 5,               # 平滑步进量
        "safety_pwm": 150,            # 传感器失效时的安全 PWM
        "fans": {},                   # 风扇配置（动态生成）
        "presets": {}                 # 用户的自定义预设
    }


def _default_fan_config(channel_id: str, label: str) -> dict:
    """生成单个风扇的默认配置"""
    return {
        "channel_id": channel_id,
        "label": label,
        "display_name": "",           # 用户自定义名称（CPU风扇/机箱风扇/水泵），空则用默认标签
        "mode": "auto",               # "auto"=曲线 | "manual"=手动
        "sensor_id": None,            # 绑定的温度传感器 ID
        "manual_pwm": 128,            # 手动模式下的 PWM 值
        "curve": [                    # 默认曲线（温度→PWM）
            {"temp": 30, "pwm": 50},
            {"temp": 40, "pwm": 100},
            {"temp": 50, "pwm": 160},
            {"temp": 60, "pwm": 255}
        ],
        "min_pwm": 30,                # 最低 PWM（防停转）
        "safety_pwm": 150             # 传感器失效安全值
    }


class ConfigManager:
    """管理 JSON 配置文件的读写"""

    def __init__(self, config_file: str = None):
        self.config_file = config_file or DEFAULT_CONFIG_FILE
        self._config: Optional[dict] = None
        self._ensure_dir()

    def _ensure_dir(self):
        """确保配置目录存在"""
        config_dir = os.path.dirname(self.config_file)
        if config_dir and not os.path.isdir(config_dir):
            try:
                os.makedirs(config_dir, exist_ok=True)
                logger.info("创建配置目录: %s", config_dir)
            except OSError as e:
                logger.error("无法创建配置目录 %s: %s", config_dir, e)

    def load(self) -> dict:
        """加载配置文件（不存在则返回默认配置）"""
        if self._config is not None:
            return self._config

        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, "r", encoding="utf-8") as f:
                    self._config = json.load(f)
                logger.info("配置已加载: %s", self.config_file)
            else:
                logger.info("配置文件不存在，使用默认配置")
                self._config = _default_config()
                self.save()
        except (json.JSONDecodeError, OSError) as e:
            logger.error("配置加载失败: %s，使用默认配置", e)
            self._config = _default_config()

        return self._config

    def save(self):
        """保存配置到文件"""
        if self._config is None:
            return
        try:
            config_dir = os.path.dirname(self.config_file)
            os.makedirs(config_dir, exist_ok=True)
            with open(self.config_file, "w", encoding="utf-8") as f:
                json.dump(self._config, f, indent=2, ensure_ascii=False)
            logger.debug("配置已保存: %s", self.config_file)
        except OSError as e:
            logger.error("配置保存失败: %s", e)

    def get(self, key: str, default=None):
        return self.config.get(key, default)

    def set(self, key: str, value):
        self.config[key] = value
        self.save()

    @property
    def config(self) -> dict:
        if self._config is None:
            return self.load()
        return self._config

    def get_fan_config(self, channel_id: str) -> dict:
        """获取指定风扇的配置（不存在则创建默认）"""
        cfg = self.config
        if channel_id not in cfg.get("fans", {}):
            # 自动创建默认配置
            label = channel_id.replace("_pwm", " PWM")
            cfg["fans"][channel_id] = _default_fan_config(channel_id, label)
            self.save()
        return cfg["fans"][channel_id]

    def set_fan_config(self, channel_id: str, fan_cfg: dict):
        """更新指定风扇的配置"""
        cfg = self.config
        cfg["fans"][channel_id] = fan_cfg
        self.save()

    def to_dict(self) -> dict:
        return self.config
