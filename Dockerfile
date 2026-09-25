# fn-fan-control: Docker 冒烟测试
# 模拟 fnOS 环境（Debian + Python3 + Flask），用 mock hwmon 目录跑通
# 「发现传感器 → 读温度 → 曲线算 PWM → 写回」全链路。
# 用法: docker build -t fn-fan-control . && docker run --rm -p 8190:8190 fn-fan-control
# 冒烟: docker run --rm -e FAN_SMOKE=1 fn-fan-control

FROM python:3.11-slim

WORKDIR /app

# smartmontools 提供 smartctl（容器内无真实硬盘，仅保证依赖存在）
RUN apt-get update && apt-get install -y --no-install-recommends smartmontools curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask

# 复制源码
COPY src/ /app/src/

# mock hwmon 目录（构建期在普通路径准备，避开只读的 /sys）
# hwmon0: 主板 nct6798（pwm1+fan1+temp1）；hwmon1: CPU coretemp（仅温度）
RUN mkdir -p /mock/hwmon/hwmon0 /mock/hwmon/hwmon1 /vol2/fan-control \
    && echo "nct6798"  > /mock/hwmon/hwmon0/name \
    && echo "128"      > /mock/hwmon/hwmon0/pwm1 \
    && echo "1"        > /mock/hwmon/hwmon0/pwm1_enable \
    && echo "800"      > /mock/hwmon/hwmon0/fan1_input \
    && echo "42000"    > /mock/hwmon/hwmon0/temp1_input \
    && echo "coretemp" > /mock/hwmon/hwmon1/name \
    && echo "45000"    > /mock/hwmon/hwmon1/temp1_input

# 启动脚本：
# - FAN_SMOKE=1 时以 mock hwmon 运行 daemon，3 个控制周期后自检并输出结果
# - 默认前台运行 daemon（生产形态，fnOS 真机走真实 /sys/class/hwmon）
COPY smoke.sh /usr/local/bin/smoke.sh
RUN chmod +x /usr/local/bin/smoke.sh

EXPOSE 8190

# 默认前台 daemon；冒烟测试用 -e FAN_SMOKE=1 覆盖 CMD
CMD ["/usr/local/bin/smoke.sh"]
