# -*- coding: utf-8 -*-
"""fn-fan-control: 温度采集模块
从多个来源读取温度：HDD SMART / NVIDIA GPU / 主板 hwmon / NVMe SSD
"""

import os
import subprocess
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

# 允许用环境变量覆盖 hwmon 根路径（Docker 冒烟测试指向 mock 目录；生产默认不变）
HWMON_BASE = os.environ.get("FAN_HWMON_BASE", "/sys/class/hwmon")


# ─────────────────────────────────────────────────────────────
# 数据结构
# ─────────────────────────────────────────────────────────────

class Sensor:
    """一个温度传感器"""

    def __init__(self, sensor_id: str, label: str, source: str, path: str = ""):
        self.id = sensor_id          # 唯一标识，如 "hdd_sda", "gpu_0", "hwmon_2_temp1"
        self.label = label           # 用户可读名称，如 "硬盘 sda", "GPU 0"
        self.source = source         # 来源类型: "hdd" | "gpu" | "hwmon" | "nvme"
        self.path = path             # 读取路径（hwmon）或设备名（hdd）
        self.value: Optional[float] = None
        self.error: Optional[str] = None

    def read(self):
        """读取当前温度，更新 self.value / self.error"""
        try:
            if self.source == "hdd":
                self._read_smartctl()
            elif self.source == "gpu":
                self._read_nvidia_smi()
            elif self.source in ("hwmon", "nvme"):
                self._read_hwmon()
            self.error = None
        except Exception as e:
            self.error = str(e)
            logger.warning("传感器 %s 读取失败: %s", self.id, e)

    def _read_smartctl(self):
        """通过 smartctl 读取硬盘温度"""
        dev = self.path  # 如 /dev/sda
        result = subprocess.run(
            ["smartctl", "-A", dev],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0:
            raise RuntimeError(f"smartctl {dev} returncode={result.returncode}")

        # 尝试不同格式的 SMART 属性
        for line in result.stdout.splitlines():
            # ATA 格式: 190 Airflow_Temperature_Cel ... 35
            if "Temperature_Celsius" in line:
                parts = line.split()
                self.value = float(parts[9])
                return
            # NVMe 格式 (smartctl --json 或文本)
            if "Temperature:" in line:
                temp_str = line.split(":")[1].strip().split()[0]
                self.value = float(temp_str)
                return

        raise RuntimeError(f"smartctl {dev}: 未找到温度字段")

    def _read_nvidia_smi(self):
        """通过 nvidia-smi 读取 GPU 温度"""
        idx = self.path  # GPU index 如 "0"
        result = subprocess.run(
            ["nvidia-smi", f"--id={idx}",
             "--query-gpu=temperature.gpu",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0:
            raise RuntimeError(f"nvidia-smi GPU {idx} 失败: {result.stderr}")
        self.value = float(result.stdout.strip())

    def _read_hwmon(self):
        """通过 /sys/class/hwmon 读取温度（self.path 形如 "hwmon3" 或 "hwmon3/temp2"）"""
        hwmon_dir, temp_file = self._split_hwmon_path()
        temp_path = os.path.join(HWMON_BASE, hwmon_dir, temp_file)

        with open(temp_path, "r") as f:
            raw = int(f.read().strip())
        value = raw / 1000.0  # 毫摄氏度 → 摄氏度

        # 悬空通道过滤：主板 Super-I/O 未接线的通道常读出 90~127℃ 垃圾值
        # （NCT6798 的 SYSTIN/AUXTIN* 实测 107~111℃），超出物理合理范围即视为无效
        if value <= -30 or value >= 100:
            raise RuntimeError(f"温度读数 {value}℃ 超出合理范围，判定为悬空通道")

        self.value = value

    def _split_hwmon_path(self) -> Tuple[str, str]:
        """把 self.path 拆成 (hwmon 目录名, temp 文件名)；未指定通道时自动挑第一个有效的"""
        if "/" in self.path:
            hwmon_dir, temp_file = self.path.split("/", 1)
            # 存入时用的是通道名（temp2），实际文件名带 _input 后缀
            if not temp_file.endswith("_input"):
                temp_file += "_input"
            return hwmon_dir, temp_file
        # 未指定 temp 通道：优先 temp1_input，否则找任意 tempX_input
        if os.path.exists(os.path.join(HWMON_BASE, self.path, "temp1_input")):
            return self.path, "temp1_input"
        for f in sorted(os.listdir(os.path.join(HWMON_BASE, self.path))):
            if f.startswith("temp") and f.endswith("_input"):
                return self.path, f
        raise RuntimeError(f"{self.path} 下无温度通道")

    def to_dict(self) -> dict:
        return {
            "id": self.id, "label": self.label,
            "source": self.source, "path": self.path,
            "value": self.value, "error": self.error
        }


# ─────────────────────────────────────────────────────────────
# 传感器管理器：自动发现 + 批量读取
# ─────────────────────────────────────────────────────────────

class VirtualSensor(Sensor):
    """虚拟传感器：由一批物理传感器聚合而成（如「全部硬盘最高温」）

    多盘位机箱里，进风风扇应当跟随最热的那块盘，而不是某一块固定盘；
    成员按 source 动态匹配，硬盘增减时自动适应。
    """

    def __init__(self, sensor_id: str, label: str, source_filter: str):
        super().__init__(sensor_id, label, "virtual")
        self.source_filter = source_filter   # 参与聚合的来源，如 "hdd"
        self.members: List[str] = []         # 本次实际参与的传感器 id（便于排查）

    def read_with(self, sensors: List["Sensor"]):
        """依赖物理传感器读取完毕后调用，聚合其有效值（当前取最大值）"""
        vals = [(s.id, s.value) for s in sensors
                if s.source == self.source_filter and s.value is not None]
        self.members = [i for i, _ in vals]
        if not vals:
            self.value = None
            self.error = f"无可用 {self.source_filter} 温度"
            return
        self.value = max(v for _, v in vals)
        self.error = None


class SensorManager:
    """管理所有温度传感器的发现和读取"""

    def __init__(self):
        self.sensors: List[Sensor] = []
        self._hdd_cache: List[str] = []       # 已发现的硬盘设备
        self._gpu_cache: List[str] = []       # 已发现的 GPU index

    def discover(self):
        """自动发现所有可用的温度传感器"""
        self.sensors.clear()
        self._discover_hdds()
        self._discover_gpus()
        self._discover_hwmon()
        # 虚拟传感器：全部硬盘最高温（进风风扇跟随最热的那块盘）
        self.sensors.append(VirtualSensor("max_hdd", "硬盘最高温", "hdd"))
        logger.info("发现 %d 个温度传感器", len(self.sensors))

    def _discover_hdds(self):
        """发现机械硬盘（通过 /dev/sd* 设备）"""
        self._hdd_cache.clear()
        try:
            import glob
            for dev in sorted(glob.glob("/dev/sd[a-z]")):
                # 过滤掉 SSD（如果有 NVMe 的盘不会被列出为 sd*，但 SATA SSD 会）
                # 简单起见，所有 sd* 都当作 HDD/SSD 处理
                self._hdd_cache.append(dev)
                self.sensors.append(Sensor(
                    sensor_id=f"hdd_{os.path.basename(dev)}",
                    label=f"硬盘 {os.path.basename(dev)}",
                    source="hdd",
                    path=dev
                ))
        except Exception as e:
            logger.warning("硬盘发现失败: %s", e)

    def _discover_gpus(self):
        """发现 NVIDIA GPU"""
        self._gpu_cache.clear()
        try:
            result = subprocess.run(
                ["nvidia-smi", "--list-gpus"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                for i, line in enumerate(result.stdout.strip().splitlines()):
                    self._gpu_cache.append(str(i))
                    self.sensors.append(Sensor(
                        sensor_id=f"gpu_{i}",
                        label=f"GPU {i}",
                        source="gpu",
                        path=str(i)
                    ))
        except FileNotFoundError:
            logger.info("nvidia-smi 未安装，跳过 GPU 发现")
        except Exception as e:
            logger.warning("GPU 发现失败: %s", e)

    def _discover_hwmon(self):
        """逐通道发现 hwmon 温度传感器（每个 tempX_input 一个条目，带 _label 命名）"""
        if not os.path.isdir(HWMON_BASE):
            return

        for hwmon_name in sorted(os.listdir(HWMON_BASE)):
            hwmon_path = os.path.join(HWMON_BASE, hwmon_name)

            # 读芯片名
            name_file = os.path.join(hwmon_path, "name")
            if not os.path.exists(name_file):
                continue
            try:
                with open(name_file) as f:
                    chip_name = f.read().strip()
            except Exception:
                continue

            temp_files = [f for f in os.listdir(hwmon_path)
                         if f.startswith("temp") and f.endswith("_input")]
            if not temp_files:
                continue

            def _num(name: str) -> int:
                try:
                    return int(name.replace("temp", "").replace("_input", ""))
                except ValueError:
                    return 99
            temp_files.sort(key=_num)

            for tf in temp_files:
                ch = tf.replace("_input", "")          # 如 temp2
                # 通道标签（驱动提供则用，如 "Core 0" / "SYSTIN" / "Composite"）
                try:
                    with open(os.path.join(hwmon_path, f"{ch}_label")) as f:
                        ch_label = f.read().strip()
                except Exception:
                    ch_label = ""

                sensor_id = f"hwmon_{hwmon_name}/{ch}"
                source = "nvme" if "nvme" in chip_name.lower() else "hwmon"

                # 组用户可读名称：<芯片类别> <通道标签/通道号>
                if "coretemp" in chip_name.lower():
                    cat = "CPU"
                elif "nvme" in chip_name.lower():
                    cat = "NVMe"
                elif "drivetemp" in chip_name.lower():
                    cat = "SATA盘"
                elif "nct" in chip_name.lower() or "it86" in chip_name.lower():
                    cat = "主板"
                else:
                    cat = chip_name

                if ch_label and ch_label != "-":
                    label = f"{cat} {ch_label}"
                else:
                    label = f"{cat} {ch.upper()}"

                # 排除明显的无效通道：读数 0 的未启用通道（如 PCH_*）与悬空高值
                # 注意：发现期只做静态排除（0℃），悬空高值在读取期过滤（可能开机时才显现）
                try:
                    with open(os.path.join(hwmon_path, tf)) as f:
                        raw = int(f.read().strip()) / 1000.0
                except Exception:
                    continue
                if raw == 0:
                    continue

                self.sensors.append(Sensor(
                    sensor_id=sensor_id,
                    label=label,
                    source=source,
                    path=f"{hwmon_name}/{ch}"
                ))

    def read_all(self):
        """批量读取所有传感器：先读物理传感器，再聚合虚拟传感器（依赖前者结果）"""
        virtuals = []
        for s in self.sensors:
            if isinstance(s, VirtualSensor):
                virtuals.append(s)
            else:
                s.read()
        for v in virtuals:
            v.read_with(self.sensors)

    def get_sensor(self, sensor_id: str) -> Optional[Sensor]:
        """按 ID 获取传感器"""
        for s in self.sensors:
            if s.id == sensor_id:
                return s
        return None

    def get_max_hdd_temp(self) -> Optional[float]:
        """获取所有 HDD 的最高温度"""
        temps = [s.value for s in self.sensors
                 if s.source == "hdd" and s.value is not None]
        return max(temps) if temps else None

    def to_dict(self) -> List[dict]:
        return [s.to_dict() for s in self.sensors]
