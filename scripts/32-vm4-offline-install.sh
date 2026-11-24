#!/bin/bash
# VM4 part 2: offline vLLM image load + model run.
# Run from VM1 over SSH AFTER artifacts were copied (see 31-*):
#   scp ~/vm4-artifacts/vllm-openai.tar admin1@192.168.100.14:~/
#   scp -r ~/vm4-artifacts/model        admin1@192.168.100.14:~/
#   ssh admin1@192.168.100.14
#   sudo bash /home/admin1/32-vm4-offline-install.sh
# Must run via sudo: needs docker, /opt/models, ufw.
# Internet on VM4 is assumed CLOSED at this point - everything from tar.

set -euo pipefail

VM3_IP=192.168.100.13
MODEL=Qwen2.5-1.5B-Instruct
ART=/home/admin1/vm4-incoming   # scp put vllm-openai.tar and model/ here

echo "== [VM4] Loading docker image from tar =="
if [ -f $ART/vllm-cpu-v034.tar.gz ]; then
  # v0.34.0: rebuild with separate _C_AVX2 kernels (host CPU has no AVX-512)
  gunzip -c $ART/vllm-cpu-v034.tar.gz | docker load
else
  docker load -i $ART/vllm-openai.tar
fi
docker image ls

echo "== [VM4] Placing model =="
mkdir -p /opt/models
if [ -d $ART/model ]; then
  rm -rf /opt/models/Qwen2.5-1.5B-Instruct.bak 2>/dev/null || true
  mv /opt/models/$MODEL /opt/models/Qwen2.5-1.5B-Instruct.bak 2>/dev/null || true
  mv $ART/model /opt/models/$MODEL
fi
ls -la /opt/models/$MODEL | head

echo "== [VM4] Starting vLLM (OpenAI-compatible, port 8000) =="
docker rm -f vllm 2>/dev/null || true
# GPU mode only if nvidia-smi really exists; otherwise CPU image
# (vllm/vllm-openai:latest requires CUDA and will not start on CPU;
# CPU builds live in the vllm/vllm-openai-cpu repo).
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  docker run -d --name vllm --restart unless-stopped \
    --runtime nvidia --gpus all \
    -v /opt/models:/models \
    -p 8000:8000 \
    vllm/vllm-openai:latest \
    --model /models/$MODEL --host 0.0.0.0 --port 8000 --dtype auto
else
  docker run -d --name vllm --restart unless-stopped \
    --shm-size=1g \
    -e VLLM_CPU_KVCACHE_SPACE=2 \
    -v /opt/models:/models \
    -p 8000:8000 \
    vllm/vllm-openai-cpu:v0.34.0 \
    /models/$MODEL --host 0.0.0.0 --port 8000 \
    --max-model-len 4096 --served-model-name $MODEL
fi

echo "== [VM4] UFW: icmp, ssh, port 8000 for VM3 only =="
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow from $VM3_IP to any port 8000 proto tcp comment 'vLLM for VM3'
# Close internet on VM4 (per task): outgoing traffic only into the lab net
ufw default deny outgoing
ufw allow out 22/tcp
ufw allow out to 192.168.100.0/24
ufw --force enable
ufw status verbose

echo "== [VM4] Waiting for model to load, checking API =="
sleep 30
curl -s http://127.0.0.1:8000/v1/models | head -c 500 || echo "(model still loading - check later: docker logs vllm)"