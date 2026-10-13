# PM.md — 项目上下文恢复点

> 更新时间: 2026-10-13T21:10:00+08:00 ｜ 结构: §A 现势快照 / §B 活跃计划与待办 / §C 设计决策索引 / §D 教训固化库 / §E 归档与回写纪律

## §A 现势快照

# fn-fan-control 项目快照（2026-10-13 第二十三次更新：交付归档完成 ✅）

- 项目：飞牛 fnOS 风扇控制应用（fpk 包），工作区 D:\projects\fancontrol
- 阶段：**交付归档完成**——0.3.1 运行中（GPU 48℃→35%），源码/安装包/配置快照/版本标签四重保全
- **归档清单**：
  1. GitHub：master=1296473（0.3.1 源码 + 方案文档 + 部署脚本），标签 **v0.3.1** 已推
  2. 可安装包：本地 `dist/fan-control_0.3.1.fpk` + NAS 持久化 `/vol2/fan-control/dist/`（已修 644 权限）
  3. 配置快照：`docs/fan-config-0.3.1.json`（12 通道绑定曲线，重装后可直接回灌）
  4. 恢复点：PM.md（本文）+ PM.md.bak + reports/DIMM2 故障报告
- 归档时运行态：GPU 48℃→35%/1699rpm；全部 8 通道 auto 正常，无失速告警
- 显卡噪音封顶结论（本轮定稿）：用户实测 80% 太吵 ✗ → **60%（3022 rpm）可接受 ✓**；曲线 40→30% | 55→40% | 65→50% | 75→60% | 80→60% 封顶；ComfyUI 满载验证收敛于 78-80℃（开盖）；换扇方案否决（限高 15mm + 价格 + 现状够用）
- 待办（非阻塞）：BIOS 将 SYS_FAN3 切 DC 模式（3pin M.2 风扇才受控）；SYS_FAN4 四扇建议 SATA 供电 hub；合盖后如需复核喊我
- 环境：内核 6.18.18.c1107-trim；out-of-tree nct6687d 驱动已持久化（**fnOS 换内核后需重编**：源码 GitHub Fred78290/nct6687d，headers 在 /usr/src）
- 迭代 SOP：改码 → 升版本号（manifest+build.sh）→ bash scripts/build.sh → sudo bash scripts/deploy.sh <fpk> <构建目录> → commit → push
- **显卡散热专题（本轮重点）**：
  1. 问题：4×B6015 满速 5128 rpm 噪音不可接受；用户要求随显卡温度调速并封顶
  2. 工具：**噪音测试**（0.3.x）——`POST /api/fan/<id>/noise-test {start,end,step,hold}` 阶梯升速、每档实测转速写日志、finally 自动还原；`/noise-stop` 可随时中断（≤0.5s）；UI 有 🎧试听 30 秒 / 🔊全档扫描 / ⏹停止
  3. 用户实测：80% 太吵 ✗，60%（3022 rpm）可接受 ✓（15cm 可闻，合盖应更轻）
  4. **最终曲线**（用户定锚：80℃=60%）：40℃→30% ｜ 55℃→40% ｜ 65℃→50% ｜ 75℃→60% ｜ 80℃→60%（硬封顶）；最低 30%，失效安全值 60%
  5. **满载热验证**（ComfyUI 真实 CUDA，11 分钟/168 采样）：100% 利用率、57-60W、温度 73→80℃、**收敛**（前半 79.0→后半 78.3，Δ-0.7）、风扇全程贴合 60% 约 3015 rpm
  6. 结论：60% 够用且收敛；**注意本次为开盖测试，合盖后需复核**；夏季环境升温会抬高平衡点
  7. 用户决定：**维持现状**（不加紧急提速、不换扇、暂不复核）
  8. ~~后续可选改善：换 NF-A6x25~~ **已否决**：机箱限高 15mm 装不进 25mm 厚扇；且 ComfyUI 非 A3000 真实用途（真实工况远轻于满 CUDA），现状够用 → 维持现状
- 绑定全景（已应用）：CPU←CPU Package / 上层进风×3←主板System / pwm6←gpu_0 / pwm7←max_hdd / pwm5←WD SN750；pwm2 空置
- 其余别名与实测：8 通道↔接口映射由满速扫描锁定；pwm8 起转点 30%→38%（该组下限 40%）；失速保护实测 77→107 补转 0→1000rpm
- 待办：BIOS 把 SYS_FAN3 设 DC 模式（3pin M.2 风扇才受控）；SYS_FAN4 四扇建议 SATA 供电 hub；HBA 温度不可读
- 环境：内核 6.18.18.c1107-trim；out-of-tree nct6687d 驱动已持久化（换内核需重编）；scripts/deploy.sh 为部署标准流程


- 项目：飞牛 fnOS 风扇控制应用（fpk 包），工作区 D:\projects\fancontrol
- 阶段：**0.1.8 运行中，换板适配完成**——用户换 MSI Z490 Carbon（NCT6687-R），应用完整恢复温控闭环并已推 GitHub（commit 278eafc）
- 换板事件链（2026-10-13）：
  1. 硬件变化：主板更换 → 内核 6.18.18.c1032→c1107，芯片 NCT6798→**NCT6687-R**，通道 hwmon7/6路→hwmon6/8路
  2. 症状：日志 PermissionError 写 /sys/.../pwm1 被拒——mainline nct6775 对 NCT6687 的 pwm 注册为只读（-r--r--r--，root 亦拒）
  3. 排除项：nct6683.ko 存在但不认 6687 芯片（ID 不匹配）；nct6775 卸载后重载报 No such device
  4. **解法（社区标准）**：out-of-tree 驱动 Fred78290/nct6687d——本机 clone→NAS 编译（/usr/src 有精确 headers 6.18.18.c1107-trim，gcc12/make 全）→insmod→dmesg 认出 NCT6687D EC fw 1.0
  5. 持久化：nct6687.ko → /lib/modules/$K/extra + depmod -a + /etc/modules（nct6775 条目替换为 nct6687）
- 实测闭环（活体证据）：pwm1 写200→读回200 rpm 384→2400；pwm3 写240→2268、写60→**575**（双向受控）；**GPU 37℃→曲线理论 pwm85→实际 pwm85→rpm1617 分毫不差**
- 0.1.8 变更：cmd/main 三探测（nct6687→nct6775→it87，已有可写 pwm 视图则跳过）；已上机（nct6687×3 确认）
- 注意事项：fnOS 换内核版本后 nct6687.ko 需重编（cd /tmp/nct6687d && make && 拷贝+depmod）；应用侧零改动适配换板（通道自动重枚举，配置按 channel_id 保留，hwmon 编号恰好未变）
- Git：master 278eafc 已推 GitHub；本地身份 faiths 占位
- 运行态：PORT UP；sensors=33 fans=8；温控闭环正常
- 遗留（非阻塞）：用户识别命名风扇；tests 补用例；A8/A9 补测；DIMM2 故障报告（reports/，换板起因）已入 git

## §B 活跃计划与待办

# 活跃计划与待办（2026-10-13 二十次更新：换板适配闭环）

## 已完成
- [x] 0.1.0→0.1.8 全程：打包/真机验收 A1–A7/绿白 UI/悬空通道根治/识别改名/占空比显示/三芯片探测
- [x] **换板适配（MSI Z490 Carbon / NCT6687-R）**：out-of-tree nct6687d 驱动编译加载+持久化，温控闭环恢复（GPU 37℃→pwm85→rpm1617 精确）
- [x] git 基线（49a06c9）+ 0.1.8（278eafc）均已推 GitHub（FaithsCode/fancontrol）

## 待办
- [ ] 用户在 UI 逐通道识别并命名风扇（🔎 按钮）——新板 8 路，建议先跑识别
- [ ] tests 补悬空通道过滤/失效回退用例
- [ ] A8 OTA 恢复测试；A9 卸载恢复 BIOS 实测
- [ ] （NAS 侧）确认飞牛同步方向设置（9/24 删除来源）
- [ ] fnOS 升级换内核后：nct6687.ko 需重编（源码 /tmp/nct6687d + GitHub Fred78290/nct6687d）
- [ ] 后续迭代 SOP：改码 → 升版本号（manifest+build.sh）→ commit → push

## §C 设计决策索引

# 设计决策索引（2026-09-25 更新）

- Web 层最终选型：Python 标准库 http.server.ThreadingHTTPServer（零外部依赖；Flask 版废弃）→ src/web/app.py；PRD N4 真正落地
- 温度读取双通道：hwmon drivetemp 优先，smartctl subprocess 回退 → src/sensors.py
- PWM 写 /sys/class/hwmon/*/pwmN，写前置 pwm_enable=1；步进平滑（step 5 / 0.1s）→ src/fan.py
- 配置持久化 /vol2/fan-control/config.json（OTA 安全）；日志/部署副本走 $TRIM_PKGVAR（/vol1/@appdata/<app>）→ src/config.py + fpk/cmd/main
- fnOS 生命周期：包内 app/ 释放到 target/；生命周期归 cmd/main（start/stop/status），废弃 systemd 双开方案 → fpk/cmd/*
- privilege run-as=root（写 sysfs 必需，校验器 HIGH 为有意接受）→ fpk/config/privilege
- hwmon 根路径可用 FAN_HWMON_BASE 覆盖（Docker/mock 测试缝）→ sensors.py + fan.py
- 风扇通道发现条件：pwmN 与 fanN_input 同时存在 → src/fan.py
- 安装器行为：同版本号覆盖安装跳过文件解压——迭代必须升版本号（0.1.1 教训）
- 入口：iframe http://<ip>:8190/，入口 ID=fan-control.main（=appname 前缀，fnpack 强校验）→ fpk/app/ui/config

## 主题索引
- fpk 结构与错误码 → §D 教训库（fpk 结构速查/fnOS 错误码）
- 温度采集 → §C / src/sensors.py
- PWM 控制与平滑 → §C / src/fan.py
- 配置持久化与 OTA → §C / src/config.py
- Web API → §C / src/web/app.py
- 验收 A1–A9 → PRD §8；A1–A7 实测记录 → §A
- 安装器版本号行为 → §C 本节末条

## §D 教训固化库

# 教训固化库

- 【同步删除风险】无版本控制的工作区被同步客户端删除后无兜底；新项目尽早 git init。删除排查路径：回收站 $I 元数据（原始路径/时间）→ 运行中的同步进程 → 确认后再还原（2026-09-25 实战验证）
- 【同步端口实证】飞牛同步客户端控制通道走 5667 端口（连 NAS）；判断「删除是否还会传播」用探针法最直接——写标记文件等 90s 看是否消失（2026-09-25）
- 【双同步客户端陷阱】一台机器可能同时跑多个同步体系（本例：飞牛同步 + 华为云 SyncService），按进程 Path 归属判断，别凭进程名猜
- 【Windows 无管理员装 Python】exe 安装器在 SYSTEM 会话做 per-user 安装会因 Package Cache 报 MSI 0x80070003；官方 zip 发行版解压即用（D:\tools\python313），SHA256 对官方清单校验，手动加用户 PATH（2026-09-25）
- 【国内下载源】python.org 直连约 2MB/min；mirrors.huaweicloud.com/python 全速；PyPI 用 pypi.tuna.tsinghua.edu.cn/simple；Docker 镜像 fnNAS 加速器对 python 镜像 401，docker.m.daocloud.io 可绕过
- 【PowerShell 转发中文】unittest 中文 docstring 经 2>&1 管道会产生编码噪音甚至 NativeCommandError 包装，退出码不可信；以测试输出末尾 OK/FAILED 为准
- 【exe/zip 哈希对照】python.org 的 windows-*.json 清单与发布页表格文件名不同（embed vs embeddable），校验前先确认文件名一一对应
- 【Docker 构建禁写 /sys】RUN 里写 /sys/class/hwmon 在真实 Linux 构建必失败；mock 硬件建普通路径 + 代码用环境变量（FAN_HWMON_BASE）暴露测试缝
- 【ssh 远程 bash 引号】pwsh→ssh 传 bash 命令时 $() 和 2>/dev/null 会被 pwsh 先吃掉；整条命令放 pwsh 单引号变量、或写成脚本 scp 上传后 bash 执行（diagN.sh 模式好用）
- 【fnOS 真机 pwm 缺失通病】hwmon 有温度无 pwm = Super-I/O 驱动未加载（nct6775/it87）；ASRock Z490M-ITX/ac 实测 modprobe nct6775 即出 6 组 PWM（2026-09-25）
- 【fnOS app 生命周期】app/ 内容运行时释放到 target/（->/vol1/@appcenter/<app>）；可写数据在 var/（->/vol1/@appdata/<app>）；脚本内要用 target/ 与 $TRIM_PKGVAR，别假设 app/ 路径存活
- 【shell 函数内 exit 陷阱】函数里 exit 会终止整个脚本而非仅返回；status() 这类被 if 调用的辅助函数必须用 return（2026-09-25 10330 根因，改错 once 教训深刻：满足校验器加 exit 3 时忘了原语境在函数内）
- 【fnOS 错误码】10111=应用包格式不符系统版本要求（多为结构缺文件/字段非法）；10330=启动失败（健康检查 checkport 不过，常见于端口没起来）；appcenter-cli list 可看应用状态；诊断顺序：装上→手动 bash cmd/main start 看退出码与日志→再谈框架
- 【fpk 结构速查（fnpack 1.2.4）】必需：manifest、config/{privilege,resource}(JSON)、ICON.PNG(64)/ICON_256.PNG(256)、app/（含 ui/config）、cmd/ 全套 9 脚本、wizard/ 目录；入口 ID 必须 appname 前缀；Windows 打包后记得 chmod +x cmd/*

## §E 归档与回写纪律

# 归档与回写纪律

- 处置动作（创建/修改/删除文件、跑命令、部署、修复）完成后当场 pm_update 回写 §A/§B，含时间戳与结果
- 归档文件：PM-Archive.md（只读，尚未创建；超预算时 pm_update 自动迁移最大冷节）
- 备份机制：破坏性操作由插件自动轮转 PM.md.bak
- 会话收尾用 pm_commit 落账

## 教训固化（2026-09-25 删除事故）
- 无 git 仓库的工作区一旦被同步删除即无版本兜底；新项目应尽早 git init + 远端备份
- 排查文件消失：先比对回收站 $I 元数据（原始路径+删除时间）与正在运行的同步类进程（fn-sync-client/SyncService），再决定还原时机
- exe 安装器在 SYSTEM 会话中 per-user 安装会因 Package Cache 路径 0x80070003 失败；用官方 zip 发行版解压到固定目录 + 手动加 PATH 更可靠
- 国内网络从 python.org 直连下载极慢（5min/10MB）；华为云镜像 mirrors.huaweicloud.com/python 全速，PyPI 用清华镜像

## 账本
- 2026-09-24 会话首建 PM.md：工作区全量核查（PRD/源码/Web UI/fpk/测试/产物），安装 app-dev 领域规则
- 2026-09-25 删除事故处置：定位回收站元数据 → 抢救备份 → 用户确认后还原 27 文件 → 单测 13/13 通过 → Python 环境建立（D:\tools\python313 + flask）
- 2026-09-25T02:16:54.384Z 提交：Docker 冒烟测试完成：NAS 实测 mock 链路 SMOKE OK、生产形态 Web UI 局域网 200 + 7 真实温度传感器；发现并修复 nct6775 未加载问题（补进 4 个 fpk 脚本）；修 daemon.py 日志时序 bug；FAN_HWMON_BASE 测试缝 + Dockerfile 重写 + smoke.sh 新增；回归 13/13
- 2026-09-25T02:27:10.254Z 提交：硬件链路实机验证通过：nct6775 加载后 hwmon7/nct6798 暴露 6 PWM，生产容器发现 8 传感器+6 风扇通道（2 在转），风扇可控性成立；「项目没意义」疑虑解除，进入 fpk 真机验收准备
- 2026-09-25T02:46:11.322Z 提交：fpk 对齐官方 fnpack 1.2.4 规范并打包成功（36K）：补 privilege(root)/resource JSON/7 个 cmd 回调脚本，launchname 改 fan-control.main，废弃 systemd 双开方案；本地 dist 旧包作废，等用户 sudo 安装后自动验收
- 2026-09-25T02:50:46.470Z 提交：10111 排查完毕：官方校验器扫出缺 wizard/ 目录(BLOCKER)+图标命名+执行位+status exit3，全部修复后校验全绿（仅剩有意的 privilege.root）；等用户重试 sudo 安装
- 2026-09-25T02:53:22.457Z 提交：A1 通过（fpk 成功安装进 fnOS）；启动失败根因=app/释放到target/而脚本找app/src + 主机无flask；已修 cmd/main(SRC_DIR=target/src+存在性检查+存活校验) 与 install_callback(自动装flask)，等用户重装start
- 2026-09-25T02:56:58.006Z 提交：根治 10330：web/app.py 重写为标准库 ThreadingHTTPServer（API 语义不变），彻底去掉 flask 依赖；本机 daemon+API 冒烟 OK、单测 13/13；新包已就位 NAS 等用户覆盖安装+start
- 2026-09-25T05:33:15.440Z 提交：10330 深挖：diag9 证实 var/ 全空=框架 start 未跑到我们的 main；diag10.sh 已上传（手动 TRIM_PKGVAR 拉起 + appcenter-cli list），等用户 sudo 执行输出
- 2026-09-25T05:47:50.108Z 提交：10330 根因实锤修复：status() 函数内 exit 3 终止整个脚本（上轮为满足校验器改坏），改回 return 语义；新包重打就位；教训入库（shell 函数 exit 陷阱 + fnOS 错误码 + fpk 结构速查 + app 生命周期路径）
- 2026-09-25T05:50:01.698Z 提交：start 仍 10330：疑新包未重装或 daemon 闪退；diag11.sh 已上传（脚本版本鉴别+手动拉起+9s 存活观察），等用户 sudo 执行
- 2026-09-25T05:54:53.049Z 提交：覆盖安装确认上机但 start 仍 10330；diag12.sh 已上传（脚本版本鉴别/var 现场/手动拉起三合一），等用户 sudo 执行后按三分支结论修复
- 2026-09-25T05:59:19.504Z 提交：🎉 真机验收 A1–A7 全部通过：0.1.1 安装+启动+17 传感器/6 风扇发现+手动 PWM 精确生效(80→rpm935)+曲线跟随分毫不差(GPU44℃→pwm96)+安全回退；10330 系安装器同版本号跳过解压所致，升版本号解决；PM 大版本落账并备份
- 2026-09-25T06:05:39.133Z 提交：0.1.2 上线：绿白清爽主题（用户反馈）+ 下拉弹回 bug 修复（userEditing 暂停重绘）+ 下拉带实时温度；部署链又见安装器跳解压，用内层 app.tgz 强刷 target/ 解决；已验证 served UI 新版
- 2026-09-25T06:09:42.981Z 提交：悬空通道根治上线 0.1.4：逐通道枚举+_label 命名+≥100℃ 悬空拦截+UI 隐藏；全库最高 62.5℃（PCH）合理；30 传感器/6 风扇温控闭环正常；等用户确认 UI 体验
- 2026-09-25T06:23:57.618Z 提交：0.1.5 上线：🔎 识别按钮（PWM 15 降速 6s 肉眼认扇）+ ✏️ display_name 自定义命名持久化 + BIOS 对表参考；served 验证通过；等用户命名后 git init 首提
- 2026-09-25T06:34:16.834Z 提交：0.1.6 上线：UI 全面占空比 % 显示（前端 pwmToPct/pctToPwm 换算，内部 0-255 兼容旧配置）；SOP 部署 served 验证 ×7 通过
- 2026-09-25T06:38:22.803Z 提交：0.1.7（NCT/IT8 双探测）上机验证 + git init 首提 62 文件/2816 行（commit 49a06c9）+ GitHub 公钥绑定差一步（Permission denied，公钥已出示，等用户加到账号后推送）
- 2026-09-25T07:02:34.164Z 提交：🎉 项目交付闭环：0.1.7 推上 GitHub（FaithsCode/fancontrol，SSH 绑定，62 文件/2816 行）；NAS 温控闭环运行；PM 全程落账完毕
