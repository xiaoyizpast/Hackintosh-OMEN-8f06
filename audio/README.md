# 扬声器 EQ：BlackHole + CamillaDSP

HP HyperX OMEN PRO 16（8F06 / ALC245）在 macOS 下的免费系统级 EQ 方案。

## 为什么需要它

Windows 下这台机器的扬声器经过两级闭源 DSP：

```
Realtek APO（HP Gen5 PK，gen5pkey_*.mdat）
→ DTS:X Ultra（DTS APO4x，dts_gpeq_mode1_*.bin）
→ ALC245
```

Windows 听感来自：

- 100 Hz 二阶高通
- 低频增强（TBHDX）
- 400 Hz 以下 12:1 压缩 + 补偿（MBHL）
- DTS 私有 GPEQ

macOS 没有 APO，`SimpleHDA` 只提供基础输出，所以声音薄、低频少。

## 能复刻到什么程度

| 部分 | 状态 |
|---|---|
| 100 Hz 高通 | 可用 EQ 近似 |
| 低频增强 | 可用 EQ 近似 |
| DTS GPEQ | 私有编码，无法反解 |
| MBHL 动态 | 可用 CamillaDSP 压缩器近似 |

本方案使用 eqMac 的 **Small Speakers** 曲线做静态近似：

```
32Hz +11, 64 +8.5, 125 +7, 250 +5, 500 +2.5
1k 0, 2k -2.5, 4k -5, 8k -7, 16k -8.5
Preamp -6 dB
```

没有 REW 测量，属于近似，不是精确复刻。

## 链路

```
App → BlackHole 2ch → CamillaDSP（10 段 EQ）→ Realtek ALC245 → 扬声器
```

## 安装

```bash
sudo bash audio/install.sh
```

脚本会：

1. 安装 BlackHole 2ch 0.7.1（校验 SHA-256）
2. 安装 CamillaDSP 4.1.3 x86_64（校验 SHA-256）
3. 写入 `/usr/local/etc/camilladsp/omen.yml`
4. 安装 `com.local.camilladsp` LaunchAgent（KeepAlive）
5. 把默认输出设为 BlackHole

**首次运行会请求「麦克风」权限，必须允许**（CamillaDSP 用它读取 BlackHole）。

## 验证

```bash
launchctl print gui/$(id -u)/com.local.camilladsp | grep state
tail -f ~/Library/Logs/camilladsp.log
```

日志应出现：

```
The capture device supports pitch control.
```

## 调整

编辑 `/usr/local/etc/camilladsp/omen.yml` 的 `gain`，然后：

```bash
launchctl kickstart -k gui/$(id -u)/com.local.camilladsp
```

## 卸载

```bash
sudo bash audio/uninstall.sh
```

BlackHole 驱动需单独删除（脚本会提示）。

## 文件

| 文件 | 作用 |
|---|---|
| `omen.yml` | CamillaDSP 配置（10 段 PEQ + preamp） |
| `omen-eq-preset.txt` | EQ 参数，供 eqMac / SoundSource 使用 |
| `install.sh` | 安装 |
| `uninstall.sh` | 卸载 |
| `setdefault.swift` | 设置默认输出设备 |
| `camilladsp-omen.sh` | 启动包装 |

## 限制

- 采样率固定 48 kHz
- 没有 DTS GPEQ 的精确系数
- 没有 MBHL 的完整动态处理（可后续加）
- 仅 x86_64（本机平台）
