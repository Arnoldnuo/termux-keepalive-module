#!/system/bin/sh
# watchdog.sh - 主业务逻辑：保活 Termux 和 sshd

WATCHDOG_PIDFILE="/data/local/tmp/termux_watchdog.pid"
LOG="/data/local/tmp/termux_keeper.log"

# Termux 包名
TERMUX_PKG="com.termux"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WATCHDOG] $1" >> "$LOG"
}

# 写入自身 PID
echo $$ > "$WATCHDOG_PIDFILE"
log_msg "Watchdog started, PID=$$"

# 设置自身 oom 保护
echo -1000 > /proc/$$/oom_score_adj 2>/dev/null || \
echo -17 > /proc/$$/oom_adj 2>/dev/null

# ── 工具函数 ──────────────────────────────────────────────

# 获取 Termux 主进程 PID（通过 ps 找 com.termux）
get_termux_pid() {
    # Android 的 ps 格式：ps -A 输出中找包名
    ps -A 2>/dev/null | grep "com\.termux$" | grep -v grep | awk '{print $2}' | head -1
}

# 检查 sshd 是否在 Termux 进程命名空间内运行
is_sshd_running() {
    # sshd 进程由 Termux 的用户启动，检查进程列表
    ps -A 2>/dev/null | grep -E "[s]shd" | grep -v grep | head -1
    # 或者检查端口（更准确）
    # cat /proc/net/tcp6 2>/dev/null | grep -i " 0016 " # 22端口 hex=0016
}

# 检查 22 端口是否监听（更可靠的 sshd 检测方式）
is_sshd_port_open() {
    # 0016 = port 22 in hex, little-endian
    # /proc/net/tcp 和 tcp6 都检查
    grep -qi "00000000:0016" /proc/net/tcp 2>/dev/null && return 0
    grep -qi "00000000000000000000000000000000:0016" /proc/net/tcp6 2>/dev/null && return 0
    # 也有可能是 0.0.0.0:22 以其他 hex 形式出现，用更宽松的匹配
    grep -qi ":0016 " /proc/net/tcp6 2>/dev/null && return 0
    return 1
}

# 设置指定 PID 的 oom_score_adj
protect_process() {
    local pid="$1"
    local name="$2"
    if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
        echo -1000 > /proc/$pid/oom_score_adj 2>/dev/null || \
        echo -17 > /proc/$pid/oom_adj 2>/dev/null
        log_msg "Protected $name PID=$pid from OOM killer"
    fi
}

# 在后台启动 Termux（只启动 Service，完全不碰前台）
start_termux_background() {
    log_msg "Starting Termux TermuxService in background..."

    am startservice \
        -n "com.termux/.app.TermuxService" \
        --user 0 \
        2>/dev/null

    log_msg "Termux TermuxService start command sent"
    sleep 5  # 等待 service 起来
}

# ── 主循环 ────────────────────────────────────────────────

log_msg "=== Watchdog main loop starting ==="

while true; do
    # 1. 检查 Termux 进程
    TERMUX_PID=$(get_termux_pid)

    if [ -z "$TERMUX_PID" ]; then
        log_msg "Termux is NOT running, starting it..."
        start_termux_background
        sleep 10  # 等待 Termux 启动
        TERMUX_PID=$(get_termux_pid)
    fi

    # 2. 保护 Termux 进程不被 OOM 杀死
    if [ -n "$TERMUX_PID" ]; then
        protect_process "$TERMUX_PID" "Termux"

        # 同时保护 Termux 的所有子进程
        for child_pid in $(cat /proc/$TERMUX_PID/task/*/children 2>/dev/null | tr ' ' '\n' | sort -u); do
            protect_process "$child_pid" "Termux-child"
        done

        # 或者更简单地找所有 Termux uid 的进程
        TERMUX_UID=$(stat -c %u /data/data/com.termux 2>/dev/null)
        if [ -n "$TERMUX_UID" ]; then
            for pid in $(ls /proc | grep '^[0-9]'); do
                proc_uid=$(cat /proc/$pid/status 2>/dev/null | grep "^Uid:" | awk '{print $2}')
                if [ "$proc_uid" = "$TERMUX_UID" ]; then
                    protect_process "$pid" "Termux-uid-proc"
                fi
            done
        fi
    fi

    # 4. 睡眠 60 秒后再检查
    sleep 60
done
