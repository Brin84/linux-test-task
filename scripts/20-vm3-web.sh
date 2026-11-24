#!/bin/bash
# VM3 - web UI for the AI model.
# NextChat (ChatGPT-Next-Web) - lightweight, supports custom OpenAI-compatible
# endpoints; official docker image yidadaa/chatgpt-next-web.
# Docker + nginx (reverse proxy) + self-signed certificate (HTTPS).
# Run from VM1 over SSH on VM3.

set -euo pipefail

VM4_IP=192.168.100.14   # vLLM
VM1_IP=192.168.100.11   # workstation

echo "== [VM3] Installing Docker =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl ufw nginx openssl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "== [VM3] Starting NextChat =="
# BASE_URL - OpenAI-compatible endpoint of vLLM on VM4.
# OPENAI_API_KEY - any non-empty value: vLLM does not validate it, but the
# NextChat UI refuses to open a chat without a key.
docker rm -f nextchat 2>/dev/null || true
docker run -d --name nextchat --restart unless-stopped \
  -p 127.0.0.1:3000:3000 \
  -e BASE_URL=http://$VM4_IP:8000 \
  -e OPENAI_API_KEY=sk-lab-local \
  -e CUSTOM_MODELS=-all,+Qwen2.5-1.5B-Instruct \
  -e DEFAULT_MODEL=Qwen2.5-1.5B-Instruct \
  yidadaa/chatgpt-next-web

echo "== [VM3] Self-signed certificate =="
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/lab.key \
  -out /etc/nginx/ssl/lab.crt \
  -subj "/C=BY/ST=Minsk/L=Minsk/O=Lab/OU=IT/CN=vm3.lab.local" \
  -addext "subjectAltName=DNS:vm3.lab.local,IP:192.168.100.13"

echo "== [VM3] nginx reverse proxy =="
cat > /etc/nginx/sites-available/lab <<'EOF'
server {
    listen 80;
    server_name _;
    # redirect to https
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name vm3.lab.local;

    ssl_certificate     /etc/nginx/ssl/lab.crt;
    ssl_certificate_key /etc/nginx/ssl/lab.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF
ln -sf /etc/nginx/sites-available/lab /etc/nginx/sites-enabled/lab
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "== [VM3] UFW: icmp, ssh, http/https (access from VM1) =="
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
# http/https only from VM1 (per task)
ufw allow from $VM1_IP to any port 80 proto tcp comment 'HTTP from VM1'
ufw allow from $VM1_IP to any port 443 proto tcp comment 'HTTPS from VM1'
ufw --force enable
ufw status verbose

echo "== [VM3] Done: https://192.168.100.13 (self-signed) =="