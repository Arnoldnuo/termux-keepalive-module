#!/system/bin/sh

# ==================================
# App KeepAlive Worker
# ==================================

# -------- 配置区 --------
WATCH_APPS="
com.termux:com.termux.HomeActivity
"
CHECK_INTERVAL=30   # 每隔多少秒检测一次
BOOT_DELAY=60       # 开机后等待多少秒再启动
MAX_FAIL=5          # 连续失败多少次后进入冷却
COOLDOWN=300        # 冷却时间（秒）

LOG_FILE="/data/adb/modules/termux-app-keepalive/keepalive.log"
MAX_LOG_SIZE=102400  # 日志最大 100KB
# -------- 配置区结束 --------

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
    local size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
        echo "[$timestamp] Log rotated." > "$LOG_FILE"
    fi
}

is_running() {
    local pkg="$1"
    dumpsys activity processes 2>/dev/null | grep -q "$pkg"
    return $?
}

launch_app() {
    local pkg="$1"
    local activity="$2"
    monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
    sleep 2
    # monkey 失败则用 am start 兜底
    if ! is_running "$pkg"; then
        am start -n "$pkg/$activity" > /dev/null 2>&1
    fi
}

# 让 worker 自身也不容易被 OOM Killer 杀死
echo -1000 > /proc/$$/oom_score_adj

log "Worker started, waiting ${BOOT_DELAY}s for system ready..."
sleep "$BOOT_DELAY"
log "System ready, starting watch loop."

# 初次启动所有 App
for entry in $WATCH_APPS; do
    pkg=$(echo "$entry" | cut -d: -f1)
    activity=$(echo "$entry" | cut -d: -f2)
    [ -z "$pkg" ] && continue
    log "Initial launch: $pkg"
    launch_app "$pkg" "$activity"
done

# 失败计数辅助函数
get_fail() {
    local varname="FAIL_$(echo $1 | tr '.' '_')"
    eval echo \$$varname
}

set_fail() {
    local varname="FAIL_$(echo $1 | tr '.' '_')"
    eval $varname=$2
}

# 初始化所有 App 的失败计数为 0
for entry in $WATCH_APPS; do
    pkg=$(echo "$entry" | cut -d: -f1)
    [ -z "$pkg" ] && continue
    set_fail "$pkg" 0
done

# 主循环
while true; do
    sleep "$CHECK_INTERVAL"

    for entry in $WATCH_APPS; do
        pkg=$(echo "$entry" | cut -d: -f1)
        activity=$(echo "$entry" | cut -d: -f2)
        [ -z "$pkg" ] && continue

        fail=$(get_fail "$pkg")

        # 达到最大失败次数，进入冷却
        if [ "$fail" -ge "$MAX_FAIL" ]; then
            log "[$pkg] Too many failures, cooling down ${COOLDOWN}s..."
            sleep "$COOLDOWN"
            set_fail "$pkg" 0
            log "[$pkg] Cooldown done, resuming."
            continue
        fi

        if ! is_running "$pkg"; then
            fail=$((fail + 1))
            set_fail "$pkg" "$fail"
            log "DEAD detected: $pkg (fail #$fail) — restarting..."
            launch_app "$pkg" "$activity"
            sleep 3
            if is_running "$pkg"; then
                log "Restarted OK: $pkg"
                set_fail "$pkg" 0
            else
                log "Restart FAILED: $pkg (fail #$fail)"
            fi
        fi

    done
done
