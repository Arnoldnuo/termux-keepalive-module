#!/system/bin/sh
# customize.sh - 模块安装时自动执行

ui_print "- Setting up Termux Keeper..."

# $MODPATH 是 KernelSU/Magisk 安装时的模块目录变量，自动注入
chmod +x "$MODPATH/service.sh"
chmod +x "$MODPATH/scripts/guardian.sh"
chmod +x "$MODPATH/scripts/watchdog.sh"

ui_print "- Permissions set successfully"
ui_print "- Termux Keeper installed!"
