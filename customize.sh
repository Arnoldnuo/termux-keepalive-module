#!/system/bin/sh
ui_print "- Installing App KeepAlive Module..."
ui_print "- Creating config directory..."

mkdir -p /data/adb/termux-keepalive
chmod 0755 "$MODPATH/service.sh"
chmod 0755 "$MODPATH/daemon.sh"
chmod 0755 "$MODPATH/keepalive.sh"

ui_print "- Done! Edit service.sh to configure your apps."
ui_print "- Log file: /data/adb/termux-keepalive/keepalive.log"
