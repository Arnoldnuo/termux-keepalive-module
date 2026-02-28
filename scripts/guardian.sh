#!/system/bin/sh
# guardian.sh - 守护 watchdog.sh，互相保活

MODDIR="/data/adb/modules/termux_keeper"
WATCHDOG="$MODDIR/scripts/watchdog.sh"
GUARDIAN_PIDFILE="/data/local/tmp/termux_guardian.pid"
WATCHDOG_PIDFILE="/data/local/tmp/termux_watchdog.pid"
LOG="/data/local/tmp/termux_keeper.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [GUARDIAN] $1" >> "$LOG"
}

# 写入自身 PID
echo $$ > "$GUARDIAN_PIDFILE"
log_msg "Guardian started, PID=$$"

# 设置 guardian 自身的 oom_score_adj，避免被系统杀死
echo -1000 > /proc/$$/oom_score_adj 2>/dev/null || \
echo -17 > /proc/$$/oom_adj 2>/dev/null

start_watchdog() {
    log_msg "Starting watchdog..."
    nohup setsid sh "$WATCHDOG" >> "$LOG" 2>&1 &
    WATCHDOG_PID=$!
    echo $WATCHDOG_PID > "$WATCHDOG_PIDFILE"
    log_msg "Watchdog started, PID=$WATCHDOG_PID"
}

# 初次启动 watchdog
start_watchdog

while true; do
    sleep 30  # 每 30 秒检查一次 watchdog 是否存活

    if [ -f "$WATCHDOG_PIDFILE" ]; then
        WATCHDOG_PID=$(cat "$WATCHDOG_PIDFILE")
        # 检查进程是否真实存在
        if ! kill -0 "$WATCHDOG_PID" 2>/dev/null; then
            log_msg "Watchdog (PID=$WATCHDOG_PID) is dead, restarting..."
            start_watchdog
        fi
    else
        log_msg "Watchdog PID file missing, restarting..."
        start_watchdog
    fi
done
