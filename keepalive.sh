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

# 检查 App 进程是否存在
is_running() {
    local pkg="$1"
    # 用 ps 检测包名进程
    ps -ef | grep -v grep | grep "$pkg" > /dev/null 2>&1
    return $?
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

# 启动 App（只拉起，不弹到前台打扰用户）
launch_app() {
    local pkg="$1"
    local activity="$2"
    log "monkey launch app: $pkg, $activity"
    # monkey 方式：静默拉起，不弹前台
    # monkey 会导致禁用屏幕旋转的功能被关闭，所以要先保留屏幕旋转状态，然后monkey启动后再恢复
    # 保存当前旋转状态
    rotation=$(settings get system accelerometer_rotation)
    monkey -p "$pkg" -c android.intent.category.LAUNCHER --pct-syskeys 0 --pct-anyevent 0 --pct-nav 0 --ignore-crashes --ignore-timeouts 1 > /dev/null 2>&1
    settings put system accelerometer_rotation "$rotation"

    # 如果 monkey 失败，用 am start 兜底
    if ! is_running "$pkg"; then
        log "am start launch app: $pkg, $activity"
        am start -n "$pkg/$activity" > /dev/null 2>&1
    fi
    # 等待进程启动后设置 oom_score_adj
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