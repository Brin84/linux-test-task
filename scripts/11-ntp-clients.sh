#!/bin/bash
# NTP-клиенты VM1, VM3, VM4 → синхронизация с VM2 (192.168.100.12).
# Ubuntu 24.04 использует systemd-timesyncd — переводим его на наш сервер.

set -euo pipefail

NTP_SERVER=192.168.100.12

echo "== [$(hostname)] Настройка timesyncd на $NTP_SERVER =="
mkdir -p /etc/systemd/timesyncd.conf.d
cat > /etc/systemd/timesyncd.conf.d/lab-ntp.conf <<EOF
[Time]
NTP=$NTP_SERVER
FallbackNTP=
EOF

systemctl restart systemd-timesyncd
timedatectl set-ntp true

echo "== [$(hostname)] Статус =="
timedatectl status
timedatectl timesync-status || true
timedatectl show-timesync -p ServerAddress -p Synchronization 2>/dev/null || true

echo "== [$(hostname)] Готово: клиент синхронизируется с $NTP_SERVER =="
