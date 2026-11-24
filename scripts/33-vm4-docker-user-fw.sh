#!/bin/bash
# VM4: DOCKER-USER filtering for the vllm published port 8000.
# Docker's published ports bypass ufw (DNAT goes through the DOCKER chain in
# FORWARD, not INPUT), so the "8000 from VM3 only" task requirement must be
# enforced in DOCKER-USER. Installed by a systemd oneshot unit running after
# docker.service so the rules survive docker restarts and reboots.
# Idempotent and self-cleaning: purges stale copies, then re-inserts.

set -u

IFACE=eth0
PORT=8000
ALLOWED=192.168.100.13

# docker recreates its chains asynchronously on (re)start; wait for them
for i in $(seq 1 30); do
  iptables -L DOCKER >/dev/null 2>&1 && break
  sleep 1
done

# purge ALL previous copies of our port rules (delete by line number,
# highest first, so numbering stays valid). Everything in DOCKER-USER
# touching $PORT is ours; comments/variants don't matter.
for n in $(iptables -L DOCKER-USER --line-numbers -n | awk -v p="dpt:$PORT" 'index($0,p){print $1}' | sort -rn); do
  iptables -D DOCKER-USER "$n"
done

# re-insert: DROP first, then ACCEPT above it
iptables -I DOCKER-USER 1 -i "$IFACE" -p tcp --dport "$PORT" -j DROP
iptables -I DOCKER-USER 1 -i "$IFACE" -p tcp --dport "$PORT" -s "$ALLOWED" -j ACCEPT -m comment --comment "vllm allow VM3 only"

iptables -S DOCKER-USER
