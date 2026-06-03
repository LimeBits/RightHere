#!/bin/bash
# 实时监控 RightHere 扩展日志
# 用法：./monitor.sh
# 右键点击菜单项后，这里会实时显示扩展的执行情况

echo "监控 RightHereExtension 日志中（Ctrl+C 退出）..."
echo "────────────────────────────────────────"

/usr/bin/log stream \
    --predicate 'process == "RightHereExtension"' \
    --style compact \
    2>&1 | grep --line-buffered -v \
    "xpc\|connection\|PlugInKit\|AppKit\|CoreAnalytics\|LaunchService\|containermanager\|extensionkit\|processmanager\|ExtensionFoundation\|libsystem\|CFPrefs\|windowmanager\|hiservices\|AutomaticTermination\|StateRestoration\|window_proxies\|Filtering"
