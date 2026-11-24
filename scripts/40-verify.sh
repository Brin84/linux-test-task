#!/bin/bash
# Финальные проверки стенда. Выполнять с VM1.
# Использование: bash 40-verify.sh

set -uo pipefail

VM2=192.168.100.12
VM3=192.168.100.13
VM4=192.168.100.14

echo "===== 1. NTP: клиенты видят VM2 ====="
timedatectl status | grep -E "synchronized|NTP|Server"

echo ""
echo "===== 2. VM2 (ntp-сервер) ====="
ssh $VM2 "ntpq -p; sudo ufw status numbered" 2>&1 | head -20

echo ""
echo "===== 3. Веб-интерфейс (https, self-signed) ====="
curl -sk -o /dev/null -w "HTTP %{http_code} over %{scheme}\n" https://$VM3/
ssh $VM3 "sudo ufw status numbered; sudo docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>&1 | head -20

echo ""
echo "===== 4. vLLM на VM4 ====="
curl -s --max-time 5 http://$VM4:8000/v1/models | head -c 400; echo ""
ssh $VM4 "sudo ufw status numbered; sudo docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>&1 | head -20

echo ""
echo "===== 5. Инференс через OpenAI-протокол (с VM1 напрямую — должен быть отказ, ufw) ====="
curl -s --max-time 5 -X POST http://$VM4:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen2.5-1.5B-Instruct","messages":[{"role":"user","content":"Привет!"}]}' | head -c 400; echo ""
echo "(ожидаем timeout — порт 8000 открыт только для VM3)"

echo ""
echo "===== 6. Инференс изнутри VM3 (через nginx-фронт) ====="
ssh $VM3 "curl -s --max-time 60 -X POST http://$VM4:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"Qwen2.5-1.5B-Instruct\",\"messages\":[{\"role\":\"user\",\"content\":\"Скажи привет по-русски\"}]}' | head -c 600" ; echo ""

echo ""
echo "===== Проверки завершены ====="
