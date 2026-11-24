#!/bin/bash
# Run on VM1 (workstation: internet + docker available).
# Downloads vLLM image and Qwen2.5-1.5B-Instruct weights for transfer to VM4.
# NOTE: VM4 has no GPU. The old image vllm/vllm-openai:cpu was removed from
# Docker Hub; CPU builds now live in a separate repo: vllm/vllm-openai-cpu.

set -euo pipefail

# HF repo id has the org prefix (Qwen/...), but on disk/in vLLM we keep the
# short name Qwen2.5-1.5B-Instruct (NextChat expects exactly this model name).
MODEL_ID=Qwen/Qwen2.5-1.5B-Instruct
MODEL=Qwen2.5-1.5B-Instruct
WORK=~/vm4-artifacts
VM4=192.168.100.14
USER4=admin1

mkdir -p $WORK/model
cd $WORK

echo "== [VM1] Docker pull vLLM (CPU image) =="
sudo docker pull vllm/vllm-openai-cpu:latest
sudo docker save -o vllm-openai.tar vllm/vllm-openai-cpu:latest

echo "== [VM1] Downloading weights $MODEL_ID =="
# Ubuntu 24.04 blocks system-wide pip (PEP 668) -> --break-system-packages.
python3 -m pip install -q --user --break-system-packages huggingface_hub
export PATH="$HOME/.local/bin:$PATH"
hf download "$MODEL_ID" --local-dir $WORK/model

echo "== [VM1] Artifacts ready: =="
ls -lh $WORK
du -sh $WORK/model

echo "== [VM1] Transfer to VM4 (into admin1 home), then run 32-*.sh via sudo =="
echo "   scp $WORK/vllm-openai.tar $USER4@$VM4:~/"
echo "   scp -r $WORK/model $USER4@$VM4:~/"