#!/bin/bash
# VM4 — инференс-сервер. Часть 1: docker.
# ВАЖНО (по заданию): после установки docker считается, что доступ к интернету
# на VM4 закрыт. Поэтому образ vLLM и веса модели доставляются с VM1
# (см. 31-vm4-offline-install.sh и 32-vm1-push-artifacts.sh).
# Выполнять с VM1 по SSH на VM4.

set -euo pipefail

echo "== [VM4] Установка Docker (последний шаг с интернетом) =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl ufw
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "== [VM4] Docker установлен. Интернет далее считается закрытым. =="
docker --version
