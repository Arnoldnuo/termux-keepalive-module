#!/system/bin/sh
# KernelSU service.sh - 只负责拉起守护链，自己退出
# 等待系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done

# 再等 30 秒，确保 Termux 相关服务就绪
sleep 30

MODDIR="/data/adb/modules/termux_keeper"
LOG="/data/local/tmp/termux_keeper.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

log_msg "=== Termux Keeper service.sh started ==="

# 用 setsid + nohup 让 guardian 完全脱离当前进程树
# 这样 service.sh 退出后 guardian 依然存活
nohup setsid sh "$MODDIR/scripts/guardian.sh" >> "$LOG" 2>&1 &

log_msg "Guardian launched with PID $!"
# service.sh 退出，不阻塞 KernelSU
