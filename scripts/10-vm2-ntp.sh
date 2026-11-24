#!/bin/bash
# VM2 - NTP server for the lab.
# Ubuntu 24.04 (noble) replaced the old `ntp` package with `ntpsec` -
# same classic ntpd/ntpq, NOT chrony, so the task requirement holds.
# ntpsec conflicts with systemd-timesyncd, so timesyncd is removed first.
# Upstreams: time.belgim.by + FGUP VNIIFTRI (vniiftri.ru) servers.

set -euo pipefail

echo "== [VM2] Removing systemd-timesyncd (conflicts with ntpsec) =="
apt-get purge -y systemd-timesyncd || true
apt-get autoremove -y || true

echo "== [VM2] Installing ntp (pulls ntpsec on noble) =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ntp ufw

echo "== [VM2] Writing /etc/ntpsec/ntp.conf =="
CONF=/etc/ntpsec/ntp.conf
[ -f "$CONF" ] && cp -n "$CONF" "$CONF.bak"

cat > "$CONF" <<EOFCONF
# /etc/ntpsec/ntp.conf - VM2, lab NTP server
driftfile /var/lib/ntpsec/ntp.drift

# Upstreams: time.belgim.by + VNIIFTRI
server time.belgim.by iburst prefer
server ntp1.vniiftri.ru iburst
server ntp2.vniiftri.ru iburst
server ntp3.vniiftri.ru iburst

restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1
restrict 192.168.100.0 mask 255.255.255.0 nomodify notrap

interface ignore wildcard
interface listen eth0
EOFCONF

systemctl restart ntpsec
systemctl enable ntpsec

echo "== [VM2] Timezone =="
timedatectl set-timezone Europe/Minsk || true

echo "== [VM2] UFW: ntp, ssh (icmp allowed by default before.rules) =="
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 123/udp comment 'NTP'
ufw --force enable
ufw status verbose

echo "== [VM2] Done. Check in ~1 min: ntpq -p =="