#!/bin/bash
# Route the system output through BlackHole and CamillaDSP, then to the speakers.
/usr/local/bin/setdefault-blackhole "BlackHole 2ch" 2>/dev/null || true
exec /usr/local/bin/camilladsp /usr/local/etc/camilladsp/omen.yml
