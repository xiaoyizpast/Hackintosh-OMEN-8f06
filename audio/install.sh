#!/bin/bash
# OMEN 16 (8F06) speaker EQ: BlackHole 2ch -> CamillaDSP -> Realtek ALC245
set -euo pipefail

GRN=$'\033[32m'; YLW=$'\033[33m'; RED=$'\033[31m'; RST=$'\033[0m'
ok()  { printf "%s✔%s %s\n" "$GRN" "$RST" "$*"; }
warn(){ printf "%s!%s %s\n" "$YLW" "$RST" "$*"; }
die() { printf "%s✘%s %s\n" "$RED" "$RST" "$*"; exit 1; }

[[ $EUID -eq 0 ]] || exec sudo -E bash "$0" "$@"
HERE=$(cd "$(dirname "$0")" && pwd)
TARGET_USER=${SUDO_USER:-$USER}
TARGET_HOME=$(eval echo "~$TARGET_USER")
TARGET_UID=$(id -u "$TARGET_USER")
TMP=$(mktemp -d /tmp/omen-audio.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

BH_URL="https://existential.audio/downloads/BlackHole2ch-0.7.1.pkg"
BH_SHA="57b540f27a3e29c37e310e01bee0fdfab76733087e47f997ef9dccf851400dcf"
CD_URL="https://github.com/HEnquist/camilladsp/releases/download/v4.1.3/camilladsp-macos-amd64.tar.gz"
CD_SHA="b66ff5fd036344340e10e46060eaf07a1fb45b5c092fba46f116457550085564"

say() { printf "%s\n" "$*"; }
say "OMEN 16 扬声器 EQ 安装"
say "链路：App → BlackHole 2ch → CamillaDSP（10 段 EQ）→ Realtek ALC245"

# 1. BlackHole
if [[ -d /Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver ]]; then
  ok "BlackHole 2ch 已安装"
else
  say "下载 BlackHole 2ch…"
  curl -L --fail --max-time 300 -o "$TMP/BlackHole2ch.pkg" "$BH_URL"
  echo "$BH_SHA  $TMP/BlackHole2ch.pkg" | shasum -a 256 -c - >/dev/null || die "BlackHole 校验失败"
  installer -pkg "$TMP/BlackHole2ch.pkg" -target / >/dev/null
  ok "BlackHole 2ch 已安装"
  killall coreaudiod 2>/dev/null || true
  sleep 2
fi

# 2. CamillaDSP (x86_64)
if [[ -x /usr/local/bin/camilladsp ]]; then
  ok "CamillaDSP 已安装"
else
  say "下载 CamillaDSP 4.1.3…"
  curl -L --fail --max-time 300 -o "$TMP/cd.tar.gz" "$CD_URL"
  echo "$CD_SHA  $TMP/cd.tar.gz" | shasum -a 256 -c - >/dev/null || die "CamillaDSP 校验失败"
  tar -xzf "$TMP/cd.tar.gz" -C "$TMP"
  install -m 755 "$TMP/camilladsp" /usr/local/bin/camilladsp
  ok "CamillaDSP 已安装"
fi

# 3. config, wrapper, default-output helper
install -d /usr/local/etc/camilladsp
install -m 644 "$HERE/omen.yml" /usr/local/etc/camilladsp/omen.yml
install -m 755 "$HERE/camilladsp-omen.sh" /usr/local/bin/camilladsp-omen.sh
if command -v swiftc >/dev/null 2>&1; then
  swiftc -O "$HERE/setdefault.swift" -o /usr/local/bin/setdefault-blackhole
  ok "setdefault-blackhole 已编译"
else
  warn "没有 swiftc，跳过 setdefault-blackhole；请手动把输出设为 BlackHole 2ch"
fi

# 4. LaunchAgent
cat > /Library/LaunchAgents/com.local.camilladsp.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.local.camilladsp</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>/usr/local/bin/camilladsp-omen.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>5</integer>
  <key>StandardOutPath</key><string>$TARGET_HOME/Library/Logs/camilladsp.log</string>
  <key>StandardErrorPath</key><string>$TARGET_HOME/Library/Logs/camilladsp.log</string>
</dict></plist>
PLIST
chown root:wheel /Library/LaunchAgents/com.local.camilladsp.plist
chmod 644 /Library/LaunchAgents/com.local.camilladsp.plist
install -d -o "$TARGET_USER" "$TARGET_HOME/Library/Logs"
touch "$TARGET_HOME/Library/Logs/camilladsp.log"
chown "$TARGET_USER" "$TARGET_HOME/Library/Logs/camilladsp.log"

launchctl bootout "gui/$TARGET_UID/com.local.camilladsp" 2>/dev/null || true
launchctl asuser "$TARGET_UID" launchctl bootstrap "gui/$TARGET_UID" /Library/LaunchAgents/com.local.camilladsp.plist 2>/dev/null || true
launchctl asuser "$TARGET_UID" launchctl kickstart -k "gui/$TARGET_UID/com.local.camilladsp" 2>/dev/null || true

# 5. default output
if [[ -x /usr/local/bin/setdefault-blackhole ]]; then
  /usr/local/bin/setdefault-blackhole "BlackHole 2ch" || warn "设置默认输出失败，请在声音设置里手动选 BlackHole 2ch"
fi

ok "安装完成"
say ""
say "首次运行 CamillaDSP 会请求「麦克风」权限（用于读取 BlackHole），必须允许。"
say "日志：$TARGET_HOME/Library/Logs/camilladsp.log"
say "配置：/usr/local/etc/camilladsp/omen.yml"
say "卸载：sudo bash audio/uninstall.sh"
