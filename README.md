# fn-fan-control

飞牛 fnOS 风扇控制应用：读取硬盘/GPU 温度，按用户可配置的曲线自动调节主板 PWM 风扇转速。

## 功能

- 自动发现 HDD（SMART）、GPU（nvidia-smi）、主板（hwmon）温度传感器
- 每个风扇接口可独立绑定温度源 + 配置温度→转速曲线
- 手动模式：直接设置 PWM 占空比（0-255）
- Web UI 实时监控（温度/RPM/PWM）+ 曲线编辑
- fpk 应用包，飞牛应用中心一键安装/卸载
- OTA 更新后配置不丢失（存 /vol2）

## 安装

在飞牛应用中心手动安装 `.fpk` 包，安装脚本自动完成：
1. 加载 `drivetemp` 内核模块（HDD 温度）
2. 注册 systemd 服务
3. 创建配置目录

Web UI 地址：`http://<NAS-IP>:8190`

## 卸载

自动停止服务 + 恢复 BIOS 默认风扇控制 + 清理 systemd。配置保留在 /vol2（重装时恢复）。

## 目录结构

```
fancontrol/
├── PRD.md          ← 产品需求文档
├── README.md       ← 本文件
├── src/            ← Python 源码
│   ├── daemon.py   ← 主守护进程
│   ├── sensors.py  ← 温度采集
│   ├── fan.py      ← 风扇控制
│   ├── curve.py    ← 曲线插值
│   ├── config.py   ← 配置管理
│   └── web/        ← Web UI (Flask)
├── fpk/            ← fpk 打包
│   ├── manifest.json
│   ├── install.sh
│   ├── uninstall.sh
│   └── fan-control.service
└── scripts/
    └── build.sh    ← 打包脚本
```

## 打包

```bash
bash scripts/build.sh
# 输出: dist/fn-fan-control-0.1.0.fpk
```

## 依赖

- fnOS v1.1.29+（实测 trim 1.2.0604 通过）
- Python 3.8+（fnOS 自带）——**零第三方依赖**（Web 层为标准库 http.server）
- smartctl（fnOS 自带或 apt install smartmontools）
- 主板风扇驱动：安装时自动加载 nct6775（NCT 系列）/ 需要时 it87

## 许可

MIT
