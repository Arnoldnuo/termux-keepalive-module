#!/system/bin/sh

MODDIR=${0%/*}
TARGET="$MODDIR/keepalive.sh"
PIDFILE="/data/adb/termux-keepalive/daemon.pid"
LOG="/data/adb/termux-keepalive/daemon.log"

mkdir -p /data/adb/termux-keepalive

log() {
    echo "[daemon $(date '+%F %T')] $1" >> "$LOG"
}

start_worker() {
    log "starting keepalive worker"
    nohup sh "$TARGET" >> "$LOG" 2>&1 &
    echo $! > "$PIDFILE"
}

is_alive() {
    [ -f "$PIDFILE" ] || return 1
    pid=$(cat "$PIDFILE")
    kill -0 "$pid" 2>/dev/null
}

log "daemon started"

while true; do
    log "Checking $pkg running status..."
    if ! is_alive; then
        log "worker dead → restarting"
        start_worker
    fi

    sleep 15
done
