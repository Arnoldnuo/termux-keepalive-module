#!/system/bin/sh

MODDIR=${0%/*}
DAEMON="$MODDIR/daemon.sh"

# 防止重复启动
if pidof -x daemon.sh >/dev/null; then
    exit 0
fi

# 脱离 KernelSU shell
nohup sh "$DAEMON" >/dev/null 2>&1 &
