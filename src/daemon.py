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
# 失速保护参数（占空比已给但不转 → 自动补转）
# ─────────────────────────────────────────────────────────────
STALL_TACH_MIN_PWM = 40    # 低于此占空比不参与判定（避免极低速误判）
STALL_TRIGGER_CYCLES = 2   # 连续多少轮 rpm=0 判定失速
STALL_KICK_BUMP = 30       # 补转时在失速目标上再加多少
STALL_MAX_FLOOR = 140      # 补转下限上限（约 55%），防止测速线故障导致一路狂转
STALL_GIVEUP_CYCLES = 3    # 补转后仍无转速的轮数 → 判定无测速线/未接风扇，自动停用保护

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

        # 失速保护 → 平滑写入
        target = _apply_stall_guard(ch, fan_cfg, target)
        controller = _get_controller(ch.channel_id, ch)
        controller.set_target(target, smooth=smooth)

    _state["last_cycle"] = time.time()
    _state["cycle_count"] += 1


def _apply_stall_guard(ch, fan_cfg, target: int) -> int:
    """失速保护：已给足占空比但风扇不转（rpm=0）时自动补转，并记住该通道的起转下限

    - 只在 target 达到判定门槛时判定，避免极低速/刚启动误判
    - 连续 STALL_TRIGGER_CYCLES 轮为 0 才算失速
    - 补转值会作为"学到的下限"持续生效，避免"补转→回落→再失速"的来回震荡
    - stall_guard=false 的通道（3pin 无测速线、空置接口）不参与
    """
    stall = _state.setdefault("stall", {})
    st = stall.setdefault(ch.channel_id, {"count": 0, "stalled": False, "learned_min": 0})

    if not fan_cfg.get("stall_guard", True):
        st["count"] = 0
        st["stalled"] = False
        st["learned_min"] = 0
        return target

    rpm = ch.current_rpm or 0

    if target >= STALL_TACH_MIN_PWM and rpm == 0:
        st["count"] += 1
        # 补转之后仍然没转速 → 该通道大概没有测速线（3pin）或根本没接风扇：
        # 连续若干轮后自动停用保护，免去手工配置，也避免无意义告警
        if st["stalled"] and not st.get("disabled"):
            st["dead_count"] = st.get("dead_count", 0) + 1
            if st["dead_count"] >= STALL_GIVEUP_CYCLES:
                st["disabled"] = True
                st["stalled"] = False
                st["learned_min"] = 0
                logger.warning("风扇 %s 补转后仍无转速，判定无测速线/未接风扇 → 自动停用失速保护",
                               ch.channel_id)
        if st.get("disabled"):
            return target
        if st["count"] >= STALL_TRIGGER_CYCLES:
            new_floor = min(target + STALL_KICK_BUMP, STALL_MAX_FLOOR)
            if new_floor > st["learned_min"]:
                st["learned_min"] = new_floor
                logger.warning("风扇 %s 失速：目标 PWM=%d 但转速为 0，补转至 %d 并记住下限",
                               ch.channel_id, target, st["learned_min"])
            st["stalled"] = True
            return max(target, st["learned_min"])
    else:
        if st["stalled"] and rpm > 0:
            logger.info("风扇 %s 已恢复转动（%d rpm），下限保持 %d",
                        ch.channel_id, rpm, st["learned_min"])
        st["count"] = 0
        st["stalled"] = False
        st["dead_count"] = 0

    # 学到过的下限持续生效
    return max(target, st["learned_min"])


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
