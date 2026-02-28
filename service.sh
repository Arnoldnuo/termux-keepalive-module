#!/system/bin/sh

WORKER="/data/adb/modules/termux-app-keepalive/worker.sh"
LOG_FILE="/data/adb/modules/termux-app-keepalive/keepalive.log"

log() {
    mkdir -p "$(dirname $LOG_FILE)"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 让自身不容易被 OOM Killer 杀死
echo -1000 > /proc/$$/oom_score_adj

log "=== Watchdog started ==="

# 守护循环：worker 挂了就重启
while true; do
    log "Watchdog: launching worker..."
    sh "$WORKER" >> "$LOG_FILE" 2>&1
    log "Watchdog: worker exited, restarting in 15s..."
    sleep 15
done
