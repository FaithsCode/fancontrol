# 内存条故障检测报告（退货用·终版）

> **用途**：向卖家申请退换货的技术证据
> **日期**：2026-10-06
> **测试平台**：MSI MEG Z490 CARBON + Intel Core i3-10305T，飞牛 fnOS（Debian）
> **测试工具**：memtester v4.6.0（Linux 内存压力测试标准工具）

---

## 一、故障条身份信息

| 项目 | 值 |
|---|---|
| 容量 | 32 GB |
| 类型 | DDR4 UDIMM |
| 标称频率 | 2933 MHz（Part Number: `DDR4 32GB 2933MHz`） |
| 实测运行频率 | 2667 MT/s @ 1.2V（**JEDEC 默认，未超频**，dmidecode 实测） |
| **序列号（SN）** | **0000026C**（SPD 读取，dmidecode） |
| 测试槽位 | 两轮独立测试分别置于 ChannelA-DIMM1（A1）与 ChannelA-DIMM0（A0） |

## 二、测试概述

memtester v4.6.0，每次锁定 24 GB 连续内存，跑全部 14 项标准测试（Stuck Address / Compare XOR·SUB·MUL·DIV·OR·AND / Sequential Increment / Solid Bits / Checkerboard / Block Sequential / Random Value / Bit Spread / Bit Flip / Walking Ones / Walking Zeroes / 8-bit Writes / 16-bit Writes），单条独占、系统全新无负载。

**共进行两轮独立测试，分别使用不同物理插槽**，另有一根同批次对照条在相同条件下测试。

## 三、两轮测试结果

### 判定：**不合格（物理性故障，跨插槽复现）**

| 指标 | **第 1 轮（A1 槽）** | **第 2 轮（A0 槽）** |
|---|---|---|
| FAILURE 失败记录 | **2612 处** | **8799 处** |
| 通过测试项 | 6 / 14 | **1 / 14** |
| Stuck Address（地址线） | ❌ bad address line @0x7c9e97540 | ❌ 失败 |
| Compare XOR/SUB/MUL/DIV/OR/AND | ❌ 全组失败 | ❌ 全组失败 |
| Sequential Increment | ❌ 失败 | ❌ 失败 |
| Solid Bits / Checkerboard / Bit 系列 | ❌ 大面积失败 | ❌ 大面积失败 |

**两轮失败签名不完全相同（数量 2612→8799），符合随机性位错误的物理故障特征（颗粒/焊点损伤），排除固定软件因素。**

## 四、对照实验（排除环境因素）

**同批次、同标称频率（2933MHz）的另一条内存，在相同条件下测试：**

| 指标 | 故障条（本报告对象） | 对照条 |
|---|---|---|
| 第 1 轮（A1 槽） | ❌ 2612 处失败 | ✅ **18/18 项全 ok，FAILURE=0** |
| Stuck Address | ❌ | ✅ ok |

**结论**：槽位、主板、CPU、频率、系统、测试方法与参数完全相同，仅内存条不同——失败完全归因于本条内存自身物理缺陷。故障条在**两个不同插槽中均复现大规模失败**，进一步排除插槽/接触因素，锁定条体本身（bad address line 指向 PCB 地址线或颗粒物理损伤）。

## 五、补充事实

1. 两轮测试均在 **JEDEC 默认频率（2667 MT/s / 1.2V）** 下进行，未开启任何超频/XMP——排除"超频致损"抗辩
2. 该批次 4 条 32G（本条 + 两条 2933 + 一条 3000）满插时系统即出现异常，隔离测试逐条定位
3. 原始日志完整保留（memtester 标准输出，含全部失败记录与偏移地址），可随时提供

## 六、诉求

依据二手交易"商品与描述不符/存在功能性故障"条款，申请**退货退款**。

---

### 附件清单
- 附件 1：第 1 轮 memtester 完整日志（A1 槽，FAILURE_COUNT=2612）— `/vol1/memtest_dimm2.log`
- 附件 2：第 2 轮 memtester 完整日志（A0 槽，FAILURE_COUNT=8799）— `/vol1/memtest_dimm2_slotA0.log`
- 附件 3：对照条 memtester 完整日志（同槽同频，18 项全 ok）— `/vol1/memtest_dimm_a1_2933.log`
- 附件 4：dmidecode 硬件信息输出（含 SN 0000026C）

> 注：本报告由自动化测试流程生成，全部数据取自 NAS 系统 dmidecode 与 memtester 实际输出，无人工干预。
