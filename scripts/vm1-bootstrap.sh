#!/bin/bash
# VM1 (Desktop install) bootstrap, run as root: sudo bash vm1-bootstrap.sh
#   hostname vm1, sudo NOPASSWD, ssh autostart, pip for hf download,
#   permanent static network (netplan + NetworkManager) LAST - may drop ssh.
set -euo pipefail

echo "== [VM1] hostname =="
hostnamectl set-hostname vm1

echo "== [VM1] sudo NOPASSWD for admin1 =="
echo 'admin1 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/admin1-nopasswd
chmod 440 /etc/sudoers.d/admin1-nopasswd

echo "== [VM1] ssh autostart =="
systemctl enable ssh ssh.socket

echo "== [VM1] tools for artifact download =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3-pip

echo "== [VM1] permanent static network (netplan + NetworkManager) - last =="
mkdir -p /etc/netplan.bak
mv /etc/netplan/*.yaml /etc/netplan.bak/ 2>/dev/null || true
cat > /etc/netplan/01-lab.yaml <<'EOF'
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.168.100.11/24]
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses: [8.8.8.8]
EOF
chmod 600 /etc/netplan/01-lab.yaml
mkdir -p /etc/cloud/cloud.cfg.d
printf 'network: {config: disabled}\n' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
netplan apply
sleep 3
nmcli con reload 2>/dev/null || true
nmcli con up eth0 2>/dev/null || true

echo "== [VM1] done =="
hostname
ip -br a show eth0
ip route
