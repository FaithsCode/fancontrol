# -*- coding: utf-8 -*-
"""fn-fan-control: 主守护进程
循环：发现传感器 → 读温度 → 按曲线算 PWM → 写入风扇接口
同时启动 Flask Web UI（后台线程）
"""

import sys
import os
import signal
import logging
import time
import threading

# 添加 src 到 path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sensors import SensorManager
from fan import FanManager, SmoothFanController
from curve import FanCurve, PRESETS
from config import ConfigManager

# ─────────────────────────────────────────────────────────────
# 日志（先确保目录存在，再挂 FileHandler，否则首次启动报错）
# ─────────────────────────────────────────────────────────────
LOG_DIR = os.environ.get("FAN_LOG_DIR", "/vol2/fan-control")
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, "fan-control.log"), encoding="utf-8")
    ]
)
logger = logging.getLogger("fn-fan-control")

# ─────────────────────────────────────────────────────────────
# 全局状态（Web UI 也读取这个）
# ─────────────────────────────────────────────────────────────
_state = {
    "sensors": SensorManager(),
    "fans": FanManager(),
    "config": ConfigManager(),
    "controllers": {},       # channel_id → SmoothFanController
    "running": False,
    "last_cycle": None,      # 上次循环时间戳
    "cycle_count": 0,
}


def _get_controller(channel_id: str, channel):
    """获取或创建平滑控制器"""
    if channel_id not in _state["controllers"]:
        cfg = _state["config"].config
        step = cfg.get("step_size", 5)
        _state["controllers"][channel_id] = SmoothFanController(channel, step_size=step)
    return _state["controllers"][channel_id]


def _discover_all():
    """重新发现所有传感器和风扇通道"""
    _state["sensors"].discover()
    _state["fans"].discover()
    logger.info("发现完成: %d 传感器, %d 风扇通道",
                len(_state["sensors"].sensors), len(_state["fans"].channels))


def _control_cycle():
    """执行一轮控制循环：读温度 → 按曲线算 PWM → 写入"""
    cfg = _state["config"].config
    interval = cfg.get("interval", 5)
    smooth = cfg.get("smooth", True)
    global_safety = cfg.get("safety_pwm", 150)

    _state["sensors"].read_all()
    _state["fans"].read_all()

    for ch in _state["fans"].channels:
        fan_cfg = _state["config"].get_fan_config(ch.channel_id)

        # 获取绑定的温度传感器
        sensor_id = fan_cfg.get("sensor_id")
        sensor = _state["sensors"].get_sensor(sensor_id) if sensor_id else None

        if fan_cfg.get("mode") == "manual":
            # 手动模式：直接写用户指定的 PWM
            target = fan_cfg.get("manual_pwm", 128)
        elif sensor and sensor.value is not None and sensor.error is None:
            # 自动模式：曲线插值
            curve_data = fan_cfg.get("curve", [])
            if not curve_data:
                target = global_safety
            else:
                curve = FanCurve.from_dict(curve_data)
                target = curve.evaluate(sensor.value)
            # 最低转速保护
            min_pwm = fan_cfg.get("min_pwm", 30)
            target = max(target, min_pwm)
        else:
            # 传感器失效 → 安全转速
            target = fan_cfg.get("safety_pwm", global_safety)
            logger.warning("风扇 %s: 传感器 %s 失效，使用安全 PWM=%d",
                           ch.channel_id, sensor_id, target)

        # 平滑写入
        controller = _get_controller(ch.channel_id, ch)
        controller.set_target(target, smooth=smooth)

    _state["last_cycle"] = time.time()
    _state["cycle_count"] += 1


def _main_loop():
    """主循环"""
    _state["running"] = True
    logger.info("fn-fan-control 守护进程启动")

    # 初始发现
    _discover_all()

    # 确保每个风扇有默认配置
    for ch in _state["fans"].channels:
        _state["config"].get_fan_config(ch.channel_id)

    cycle = 0
    while _state["running"]:
        try:
            _control_cycle()
            cycle += 1
            if cycle % 60 == 0:  # 每 60 个周期重新发现一次
                _discover_all()
        except Exception as e:
            logger.error("控制循环异常: %s", e, exc_info=True)

        # 等待下一个周期
        interval = _state["config"].get("interval", 5)
        for _ in range(interval):
            if not _state["running"]:
                break
            time.sleep(1)

    logger.info("fn-fan-control 守护进程停止")


def _signal_handler(sig, frame):
    """优雅退出"""
    logger.info("收到信号 %d，正在停止...", sig)
    _state["running"] = False
    sys.exit(0)


def start_web_ui():
    """后台线程启动 Flask Web UI"""
    from web.app import create_app
    app = create_app(_state)

    web_port = int(os.environ.get("FAN_WEB_PORT", "8190"))
    thread = threading.Thread(
        target=app.run,
        daemon=True,
        name="web-ui"
    )
    thread.start()
    logger.info("Web UI 启动在 0.0.0.0:%d", web_port)
    return thread


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, _signal_handler)
    signal.signal(signal.SIGINT, _signal_handler)

    # 启动 Web UI（后台线程；Flask 缺失时仅告警，控制循环继续）
    try:
        start_web_ui()
    except Exception as e:
        logger.error("Web UI 启动失败（控制循环继续）: %s", e)

    # 启动主循环（前台阻塞）
    _main_loop()
