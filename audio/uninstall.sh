#!/bin/bash
set -euo pipefail
[[ $EUID -eq 0 ]] || exec sudo -E bash "$0" "$@"
TARGET_USER=${SUDO_USER:-$USER}
TARGET_UID=$(id -u "$TARGET_USER")
launchctl bootout "gui/$TARGET_UID/com.local.camilladsp" 2>/dev/null || true
rm -f /Library/LaunchAgents/com.local.camilladsp.plist
rm -f /usr/local/bin/camilladsp /usr/local/bin/camilladsp-omen.sh /usr/local/bin/setdefault-blackhole
rm -rf /usr/local/etc/camilladsp
echo "已移除 CamillaDSP 与自启。BlackHole 驱动仍在："
echo "  sudo rm -rf /Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver && sudo killall coreaudiod"
