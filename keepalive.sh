#!/system/bin/sh
# ==================================
# App KeepAlive Service
# 在这里配置需要保活的 App
# ==================================

# -------- 配置区 --------
# 格式: "包名:Activity全名"，多个用空格分隔
WATCH_APPS="
com.termux:com.termux.HomeActivity
"

CHECK_INTERVAL=30 # 每隔多少秒检测一次
BOOT_DELAY=60 # 开机后等待多少秒再启动（等系统稳定）
LOG_FILE="/data/adb/termux-keepalive/keepalive.log"
MAX_LOG_SIZE=102400 # 日志最大 100KB
# -------- 配置区结束 --------


# 日志函数
log() {
    mkdir -p "$(dirname $LOG_FILE)"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"

    # 日志超大就清空
    local size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
        echo "[$timestamp] Log rotated." > "$LOG_FILE"
    fi
}

# 检查 termux 进程是否存在，且termux-service也存在
is_running() {
    local pkg="$1"

    # 检查主进程
    if ! ps -ef | grep -v grep | grep -q "$pkg"; then
        return 1
    fi

    # 如果是 termux，额外检查 runsvdir 是否存在
    if [ "$pkg" = "com.termux" ]; then
        if ! ps -ef | grep -v grep | grep -q runsvdir; then
            log "com.termux is running but runsvdir is dead"
            return 1
        fi
    fi

    return 0
}

# 设置 oom_score_adj
set_oom_adj() {
    local pkg="$1"
    local pid=$(pidof "$pkg")
    if [ -n "$pid" ]; then
        echo -1000 > /proc/$pid/oom_score_adj
        log "Set oom_score_adj=-1000 for $pkg (pid=$pid)"
    fi
}

# 启动 App，Termux 启动后需要等 runsvdir 拉起：
launch_app() {
    local pkg="$1"
    local activity="$2"
    log "launch app: $pkg, $activity"

    if ! is_running "$pkg"; then
        log "am start launch app: $pkg, $activity"
        am start -n "$pkg/$activity" > /dev/null 2>&1
    fi

    # 如果是 termux，等待 runsvdir 启动
    if [ "$pkg" = "com.termux" ]; then
        local retry=0
        while ! ps -ef | grep -v grep | grep -q runsvdir; do
            sleep 2
            retry=$((retry + 1))
            if [ $retry -ge 10 ]; then
                log "WARNING: runsvdir still not started after 20s"
                break
            fi
        done
        log "runsvdir is up"
    fi

    sleep 2
    set_oom_adj "$pkg"
}

# 等待系统启动完成
log "KeepAlive service started, waiting ${BOOT_DELAY}s for system ready..."
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

# 主循环：持续监控
while true; do
    sleep "$CHECK_INTERVAL"

    for entry in $WATCH_APPS; do
        log "Checking $pkg running status..."
        pkg=$(echo "$entry" | cut -d: -f1)
        activity=$(echo "$entry" | cut -d: -f2)
        [ -z "$pkg" ] && continue

        if ! is_running "$pkg"; then
            log "DEAD detected: $pkg — restarting..."
            launch_app "$pkg" "$activity"
            log "Restarted: $pkg"
        else
            # 进程存在但 oom_score_adj 可能被重置，定期确保设置
            set_oom_adj "$pkg"
        fi
    done
done

# 关闭幻影进程杀手，防止termux出现[Process completed (signal 9)]的问题
device_config set_sync_disabled_for_tests persistent
device_config put activity_manager max_phantom_processes 2147483647