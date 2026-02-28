这是一个claude写的，用于在kernelSU里让termux一直保持运行脚本。

也能支持其他的应用：   修改service.sh这个文件里的WATCH_APPS 为想保活的APP就行。

在kernelSU的模块tab里把zip包加载进去就行


模块在手机上的目录：/data/adb/modules/termux-app-keepalive


参考：https://kernelsu.org/zh_CN/guide/module.html#kernelsu-modules
