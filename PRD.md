# fn-fan-control 产品需求文档（PRD）

> 项目：飞牛 fnOS 风扇控制应用
> 版本：v0.1（PRD 初稿）
> 日期：2026-09-24
> 工作区：`D:\projects\fancontrol`
> 目标平台：飞牛 fnOS v1.1.29+（Debian 底座，Docker 运行环境）

---

## 1. 背景

飞牛 fnOS 的硬件监控面板仅提供温度**查看**功能，不支持风扇转速**调节**。用户在搭建 NAS + AI 渲染节点（双卡：NVIDIA 独显 + 专业卡）后，需要：

- 硬盘温度联动排风扇转速（防止机械盘过热）
- GPU 温度联动前进风转速（渲染满载时增强散热）
- 待机时风扇低速运转（静音）

飞牛应用中心目前没有风扇控制类应用。本应用填补这一空缺。

## 2. 目标

| 编号 | 目标 | 优先级 |
|---|---|---|
| G1 | 读取系统温度源（HDD SMART / GPU / 主板），映射到 PWM 风扇接口 | P0 |
| G2 | 提供用户可配置的温度→转速曲线（Web UI） | P0 |
| G3 | 实时显示当前温度 / 转速 / PWM 占空比 | P1 |
| G4 | 打包为 fpk 应用，可在飞牛应用中心安装/卸载 | P0 |
| G5 | OTA 系统更新后自动恢复运行（不丢配置） | P1 |

## 3. 功能需求

### 3.1 温度采集

| 编号 | 功能 | 来源 | 优先级 |
|---|---|---|---|
| F1.1 | HDD 温度 | SMART（`smartctl` 或 `drivetemp` hwmon 模块） | P0 |
| F1.2 | GPU 温度 | `nvidia-smi --query-gpu=temperature.gpu`（NVIDIA 卡） | P1 |
| F1.3 | 主板温度 | `/sys/class/hwmon/hwmonX/tempY_input` | P1 |
| F1.4 | NVMe SSD 温度 | `/sys/class/hwmon/hwmonX/tempY_input`（nvme 驱动） | P2 |
| F1.5 | 自动发现所有可用温度传感器 | 枚举 hwmon + smartctl | P0 |

### 3.2 风扇控制

| 编号 | 功能 | 说明 | 优先级 |
|---|---|---|---|
| F2.1 | 枚举所有 PWM 风扇接口 | 遍历 `/sys/class/hwmon/*/pwm*` + 对应 `fan*_input`（转速） | P0 |
| F2.2 | 手动设置 PWM 值 | 用户直接指定 0–255 占空比 | P0 |
| F2.3 | 曲线模式：温度→PWM 映射 | 用户配置多段线性曲线（温度点 + PWM 值） | P0 |
| F2.4 | 每个风扇接口可独立选择温度源和曲线 | 不同风扇绑定不同传感器 | P0 |
| F2.5 | 防抖（PWM 值渐变过渡） | 避免转速突变，平滑过渡（可配置过渡时间） | P1 |
| F2.6 | 最低转速保护 | 确保风扇不低于最低 RPM（防止过热） | P0 |
| F2.7 | 传感器失效保护 | 温度源读取失败 → 回退到安全转速 | P0 |

### 3.3 Web UI（fnOS 集成）

| 编号 | 功能 | 优先级 |
|---|---|---|
| F3.1 | 风扇列表：显示每个 PWM 接口的当前温度源 / 转速 / PWM 值 / 模式 | P0 |
| F3.2 | 曲线编辑器：拖拽温度点设置曲线（或简单的分段输入框） | P0 |
| F3.3 | 实时状态面板：温度 / RPM / PWM 的实时刷新 | P1 |
| F3.4 | 手动模式开关：一键切换手动 / 曲线模式 | P0 |
| F3.5 | 配置持久化：保存到 /vol2（OTA 安全路径） | P0 |

### 3.4 fpk 打包与部署

| 编号 | 功能 | 优先级 |
|---|---|---|
| F4.1 | fpk 格式打包（manifest + 二进制 + 前端 + 安装脚本） | P0 |
| F4.2 | 安装时自动加载 `drivetemp` 内核模块 | P0 |
| F4.3 | 卸载时停止守护进程 + 恢复 BIOS 默认风扇控制 | P1 |
| F4.4 | OTA 更新后自动重启守护进程（通过 systemd 或 cron@reboot） | P1 |

## 4. 非功能需求

| 编号 | 需求 | 说明 |
|---|---|---|
| N1 | OTA 兼容 | 配置文件存 /vol2（数据盘），二进制和脚本也可存 /vol2；rootfs 内只留 systemd 单元或 cron 条目 |
| N2 | 资源占用 | CPU < 1%（空闲时），内存 < 20 MB |
| N3 | 刷新间隔 | 可配置（默认 5 秒），最低 1 秒 |
| N4 | 无网络依赖 | 全部本地运行，无外部 API 调用 |
| N5 | root 权限 | 写 /sys/class/hwmon 需要 root；fpk 应用默认以 root 运行 |

## 5. 技术架构

### 5.1 整体架构

```
┌─────────────────────────────────────────────────┐
│              fn-fan-control (fpk)                │
├─────────────────────────────────────────────────┤
│                                                  │
│  Web UI (fnOS 内嵌页面)                          │
│  ├── 风扇列表 / 曲线编辑 / 实时监控              │
│  └── 通过 REST API 与后端通信                    │
│                                                  │
│  后端守护进程 (daemon)                           │
│  ├── 温度采集模块                                │
│  │   ├── HDD SMART (smartctl / hwmon drivetemp)  │
│  │   ├── GPU (nvidia-smi 或 hwmon)               │
│  │   └── 主板 (hwmon temp)                       │
│  ├── 风扇控制模块                                │
│  │   ├── 枚举 PWM 接口                           │
│  │   ├── 曲线插值计算                            │
│  │   └── PWM 写入 (平滑过渡)                     │
│  └── 配置管理                                    │
│      ├── 读取/保存 JSON 配置 (/vol2/...)         │
│      └── 默认配置生成                            │
│                                                  │
│  fpk 打包层                                      │
│  ├── manifest.json (fpk 元数据)                  │
│  ├── 安装/卸载脚本 (加载模块/注册服务)           │
│  └── systemd 单元 或 cron@reboot                │
│                                                  │
└─────────────────────────────────────────────────┘
```

### 5.2 技术选型

| 层 | 选型 | 理由 |
|---|---|---|
| 后端语言 | **Python 3**（fnOS 自带） | 零额外依赖，快速开发 |
| 温度读取 | `smartctl`（subprocess）+ `/sys/class/hwmon/`（文件读取） | 标准接口 |
| PWM 写入 | 直接写 `/sys/class/hwmon/*/pwm*` | Linux 标准接口 |
| Web UI 框架 | Flask（轻量）或纯 HTML+JS | fnOS 内嵌页面嵌入 |
| 配置格式 | JSON | 可读可编辑 |
| 打包 | fpk（fnpack） | 飞牛应用中心格式 |
| 进程管理 | systemd unit 或 cron @reboot | OTA 后自恢复 |

### 5.3 目录结构（规划）

```
fancontrol/
├── PRD.md                    ← 本文件
├── README.md                 ← 交付文档
├── src/
│   ├── daemon.py             ← 主守护进程
│   ├── sensors.py            ← 温度采集（HDD/GPU/主板）
│   ├── fan.py                ← 风扇控制（枚举/写入/防抖）
│   ├── curve.py              ← 曲线插值
│   ├── config.py             ← 配置管理
│   └── web/
│       ├── app.py            ← Flask API
│       ├── static/           ← 前端（HTML/JS/CSS）
│       └── templates/        ← 页面模板
├── fpk/
│   ├── manifest.json         ← fpk 包描述
│   ├── install.sh            ← 安装脚本
│   ├── uninstall.sh          ← 卸载脚本
│   ├── fan-control.service   ← systemd 单元
│   └── icon.png              ← 应用图标
├── scripts/
│   ├── build.sh              ← 打包脚本
│   └── test.sh               ← 测试脚本
└── tests/
    ├── test_sensors.py       ← 温度采集测试
    ├── test_fan.py           ← 风扇控制测试
    └── test_curve.py         ← 曲线插值测试
```

## 6. fpk 应用规范（参考 kbproj 的 fpk 经验）

### 6.1 manifest.json 结构

```json
{
    "id": "fn-fan-control",
    "name": "风扇控制",
    "version": "0.1.0",
    "description": "读取硬盘/GPU温度，自动调节风扇转速",
    "author": "user",
    "icon": "icon.png",
    "type": "app",
    "ports": [],
    "volumes": [
        { "host": "/vol2/fan-control", "container": "/data" }
    ],
    "devices": [],
    "privileged": true,
    "entrypoint": "python3 /app/daemon.py"
}
```

> 注：fpk 格式需参照 kbproj 的 manifest 结构做适配（飞牛应用中心的实际要求）。

### 6.2 OTA 存活策略

| 组件 | 存放位置 | OTA 影响 |
|---|---|---|
| Python 源码 | /vol2/fan-control/src/ | ✅ 安全 |
| JSON 配置 | /vol2/fan-control/config.json | ✅ 安全 |
| systemd 单元 | /etc/systemd/system/fan-control.service | ❌ OTA 可能清除 → 安装脚本重建 |
| cron 条目 | /etc/cron.d/fan-control | ❌ OTA 可能清除 → 安装脚本重建 |
| drivetemp 模块加载 | /etc/modules | ❌ OTA 可能清除 → 安装脚本重建 |

**方案**：fpk 的 install.sh 负责写入 systemd/cron/modules；每次 fnOS OTA 后重新执行 install.sh（或通过 fnOS 的"应用修复"机制触发）。

## 7. 用户场景

### 场景 1：日常待机
- 硬盘 35℃ / GPU 40℃ / 主板 38℃
- 所有风扇 600 RPM → 总噪音 ~16 dB → 无感

### 场景 2：H3 渲染满载 + MinerU 解析
- GPU 75℃ / 硬盘 40℃ / 主板 55℃
- 前进风（绑 GPU 温度）→ 1500 RPM
- 排风扇（绑 HDD 温度）→ 1000 RPM
- 总噪音 ~25 dB → 可接受

### 场景 3：系统异常（温度源丢失）
- smartctl 读取失败 / GPU 掉线
- 守护进程检测到传感器失效 → 回退到安全 PWM（~150，中速）
- Web UI 显示"传感器异常"警告

## 8. 验收标准

| 编号 | 验收条件 |
|---|---|
| A1 | `fpk` 包可通过飞牛应用中心正常安装/卸载 |
| A2 | 安装后自动加载 drivetemp + 启动守护进程 |
| A3 | Web UI 可查看所有风扇接口的状态 |
| A4 | 修改曲线后 10 秒内生效 |
| A5 | 手动模式可直接设置 PWM 值 |
| A6 | 硬盘温度变化 → 对应风扇转速在 10 秒内跟随 |
| A7 | 温度源失效 → 风扇回到安全转速（不失控） |
| A8 | fnOS OTA 后：重新执行 install.sh → 功能恢复 |
| A9 | 卸载后：系统恢复 BIOS 默认风扇控制 |

## 9. 里程碑

| 阶段 | 内容 | 产出 |
|---|---|---|
| M1 | PRD + 架构设计 | 本文档 |
| M2 | 核心功能开发（温度采集 + PWM 写入 + 曲线） | daemon 可运行 |
| M3 | Web UI 开发 | 可通过浏览器配置 |
| M4 | fpk 打包 + fnOS 测试 | fpk 包可安装 |
| M5 | OTA 兼容测试 + 文档 | README + 交付 |

## 10. 风险与约束

| 风险 | 缓解 |
|---|---|
| fnOS 内核版本不支持 drivetemp | 回退到 smartctl 命令行读取 |
| fnOS OTA 清除 systemd 单元 | fpk 安装脚本可重跑恢复 |
| PWM 接口编号随硬件变化 | 安装时自动枚举 + Web UI 手动指定 |
| fnOS 应用中心的 fpk 格式有版本差异 | 参照 kbproj 的 manifest 结构适配 |
| 无显示器环境下调试 Web UI | 通过 Tailscale/局域网浏览器访问 |
