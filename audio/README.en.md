# Speaker EQ: BlackHole + CamillaDSP

Free system-wide EQ for the HP HyperX OMEN PRO 16 (8F06 / ALC245) on macOS.

Windows uses Realtek APO + DTS:X Ultra; macOS has neither. This routes audio through
BlackHole into CamillaDSP with a 10-band "Small Speakers" curve and back to the ALC245.

## Install

```bash
sudo bash audio/install.sh
```

Allow the Microphone permission when CamillaDSP asks (it is used to read BlackHole).

## Files

- `omen.yml` — CamillaDSP config
- `omen-eq-preset.txt` — EQ bands for eqMac / SoundSource
- `install.sh` / `uninstall.sh`

The curve is an approximation; DTS GPEQ coefficients are proprietary and were not recovered.
