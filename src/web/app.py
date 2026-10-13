# -*- coding: utf-8 -*-
"""fn-fan-control: Web API（纯标准库实现，零外部依赖）

提供 REST API 供前端页面调用：
  GET  /                    主页面（index.html）
  GET  /api/status          全量状态（传感器+风扇+配置）
  GET  /api/sensors         传感器状态
  GET  /api/config          读取配置
  POST /api/config          更新全局配置
  POST /api/discover        重新扫描传感器/风扇
  GET  /api/fan/<id>        单风扇配置+状态
  POST /api/fan/<id>        更新单风扇配置（手动模式立即生效）
  POST /api/fan/<id>/pwm    立即设 PWM（临时，不保存）
  POST /api/fan/<id>/noise-test  噪音测试：按档位阶梯升速，记录每档转速后还原
"""

import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

_TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates", "index.html")


def create_app(state: dict):
    """创建 Web 服务，绑定 daemon 的全局状态。返回带 .run() 的 Server。"""
    sensors = state["sensors"]
    fans = state["fans"]
    config = state["config"]

    class Handler(BaseHTTPRequestHandler):
        # ── 基础工具 ─────────────────────────────────────────
        def _send(self, code: int, data, ctype: str = "application/json"):
            body = data if isinstance(data, bytes) else json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", f"{ctype}; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except BrokenPipeError:
                pass

        def _json_body(self):
            try:
                n = int(self.headers.get("Content-Length", 0))
                return json.loads(self.rfile.read(n)) if n else None
            except (ValueError, json.JSONDecodeError):
                return None

        def _get_controller(self, channel_id: str, ch):
            from fan import SmoothFanController
            ctrl = state["controllers"].get(channel_id)
            if not ctrl:
                ctrl = SmoothFanController(ch)
                state["controllers"][channel_id] = ctrl
            return ctrl

        # ── 路由 ─────────────────────────────────────────────
        def do_GET(self):
            path = self.path.split("?")[0]
            if path == "/":
                try:
                    with open(_TEMPLATE, "rb") as f:
                        self._send(200, f.read(), "text/html")
                except OSError as e:
                    self._send(500, {"error": str(e)}, "text/plain")
            elif path == "/api/status":
                sensors.read_all()
                fans.read_all()
                # 透出失速保护状态（UI 显示告警徽标）
                stall = state.get("stall", {})
                fan_list = fans.to_dict()
                for item in fan_list:
                    st = stall.get(item["channel_id"], {})
                    item["stalled"] = bool(st.get("stalled"))
                    item["learned_min"] = st.get("learned_min", 0)
                self._send(200, {
                    "sensors": sensors.to_dict(),
                    "fans": fan_list,
                    "running": state.get("running", False),
                    "cycle_count": state.get("cycle_count", 0),
                    "last_cycle": state.get("last_cycle"),
                    "config": config.to_dict(),
                    "noise_test": state.get("noise_test", {}),
                })
            elif path == "/api/sensors":
                sensors.read_all()
                self._send(200, sensors.to_dict())
            elif path == "/api/config":
                self._send(200, config.to_dict())
            elif path.startswith("/api/fan/"):
                channel_id = path[len("/api/fan/"):].rstrip("/")
                ch = fans.get_channel(channel_id)
                if not ch:
                    return self._send(404, {"error": "channel not found"})
                self._send(200, {"config": config.get_fan_config(channel_id), "status": ch.to_dict()})
            else:
                self._send(404, {"error": "not found"})

        def do_POST(self):
            path = self.path.split("?")[0]
            data = self._json_body()

            if path == "/api/discover":
                sensors.discover()
                fans.discover()
                for c in fans.channels:
                    config.get_fan_config(c.channel_id)
                self._send(200, {"ok": True, "sensors": len(sensors.sensors), "fans": len(fans.channels)})

            elif path == "/api/config":
                if not data:
                    return self._send(400, {"error": "no data"})
                for key in ("interval", "smooth", "step_size", "safety_pwm"):
                    if key in data:
                        config.set(key, data[key])
                self._send(200, {"ok": True, "config": config.to_dict()})

            elif path.startswith("/api/fan/"):
                parts = path[len("/api/fan/"):].rstrip("/").split("/")
                channel_id = parts[0]
                ch = fans.get_channel(channel_id)
                if not ch:
                    return self._send(404, {"error": "channel not found"})

                if len(parts) == 1:
                    # 更新风扇配置
                    cfg = config.get_fan_config(channel_id)
                    for key in ("mode", "sensor_id", "manual_pwm", "curve", "min_pwm", "safety_pwm", "display_name", "stall_guard"):
                        if data and key in data:
                            cfg[key] = data[key]
                    config.set_fan_config(channel_id, cfg)
                    # 手动模式立即生效
                    if cfg.get("mode") == "manual":
                        self._get_controller(channel_id, ch).set_target(cfg.get("manual_pwm", 128), smooth=True)
                    self._send(200, {"ok": True, "config": cfg})

                elif len(parts) == 2 and parts[1] == "pwm":
                    # 立即设 PWM（临时）
                    pwm = (data or {}).get("pwm", 128)
                    self._get_controller(channel_id, ch).set_target(int(pwm), smooth=False)
                    self._send(200, {"ok": True, "pwm": pwm})

                elif len(parts) == 2 and parts[1] == "noise-test":
                    # 噪音测试：按档位阶梯升速（每档停留 hold 秒并记录转速），结束后还原原模式
                    d = data or {}
                    start = int(d.get("start", 30))
                    end = int(d.get("end", 100))
                    step = int(d.get("step", 10))
                    hold = int(d.get("hold", 12))
                    tests = state.setdefault("noise_test", {})
                    if tests.get(channel_id):
                        return self._send(409, {"error": "该通道正在测试中"})

                    orig = dict(config.get_fan_config(channel_id))
                    ctrl = self._get_controller(channel_id, ch)
                    state.setdefault("noise_test_log", {})

                    def _run():
                        results = []
                        state["noise_test_log"][channel_id] = results
                        try:
                            pcts = list(range(start, end + 1, step))
                            for i, pct in enumerate(pcts, 1):
                                pwm = max(0, min(255, round(pct * 255 / 100)))
                                cfg = config.get_fan_config(channel_id)
                                cfg["mode"] = "manual"
                                cfg["manual_pwm"] = pwm
                                config.set_fan_config(channel_id, cfg)
                                tests[channel_id] = {"pct": pct, "index": i, "total": len(pcts)}
                                ctrl.set_target(pwm, smooth=True)
                                time.sleep(hold)
                                rpm = ch.read_rpm()
                                results.append({"pct": pct, "pwm": pwm, "rpm": rpm})
                                # 打到 info.log：每档"占空比 → 转速"实测记录
                                print("噪音测试 %s: 第 %d/%d 档 %d%% (pwm %d) → %s rpm"
                                      % (channel_id, i, len(pcts), pct, pwm, rpm), flush=True)
                        finally:
                            # 无论成功失败都还原原配置，避免风扇卡在测试档位
                            restored = config.get_fan_config(channel_id)
                            restored["mode"] = orig.get("mode", "auto")
                            restored["manual_pwm"] = orig.get("manual_pwm", 128)
                            config.set_fan_config(channel_id, restored)
                            tests.pop(channel_id, None)
                            print("噪音测试 %s 结束，已还原为 %s 模式"
                                  % (channel_id, restored["mode"]), flush=True)

                    threading.Thread(target=_run, daemon=True).start()
                    self._send(200, {"ok": True, "start": start, "end": end,
                                     "step": step, "hold": hold,
                                     "steps": len(range(start, end + 1, step)),
                                     "note": "测试期间请听音；每档停留 %d 秒" % hold})

                else:
                    self._send(404, {"error": "not found"})
            else:
                self._send(404, {"error": "not found"})

        def log_message(self, fmt, *args):
            pass  # 静默访问日志，避免刷 info.log

    port = int(os.environ.get("FAN_WEB_PORT", "8190"))
    httpd = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    httpd.daemon_threads = True

    class Server:
        def run(self):
            httpd.serve_forever()

    return Server()
