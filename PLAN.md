# Тестовое задание: стенд из 4 VM (Hyper-V, диск E:)

## Архитектура

Гипервизор: Hyper-V (уже установлен на хосте, 16 лог. ядер).
Диск E: — 157 GB свободно. Итоговое расположение: `E:\vm-lab\`.

Внутренний коммутатор Hyper-V `LabSwitch` (Internal), подсеть `192.168.100.0/24`.
Хост: IP `192.168.100.1` на vEthernet (LabSwitch) + WinNAT для выхода VM в интернет.

| VM  | Роль | OS | IP | vCPU | RAM | Диск |
|-----|------|----|----|------|-----|------|
| VM1 | Рабочая станция | Ubuntu Desktop 24.04 | 192.168.100.11 | 2 | 4 GB | 40 GB |
| VM2 | NTP-сервер | Ubuntu Server 24.04 | 192.168.100.12 | 1 | 1 GB | 20 GB |
| VM3 | Веб-интерфейс ИИ | Ubuntu Server 24.04 | 192.168.100.13 | 2 | 2 GB | 30 GB |
| VM4 | Инференс vLLM+Qwen | Ubuntu Server 24.04 | 192.168.100.14 | 4 | 8 GB | 40 GB |

## Порядок работ

1. [x] Проверка хоста: Hyper-V установлен, 16 CPU, E: 157GB
2. [ ] Перенос vm-lab на E:\vm-lab
3. [ ] Скачать ISO Ubuntu Server 24.04 + Desktop 24.04 → E:\vm-lab\iso
4. [ ] LabSwitch (Internal) + NAT 192.168.100.0/24 на хосте
5. [ ] Создать 4 VM (Gen2, UEFI, dynamic memory off)
6. [ ] Установить ОС (server minimized + SSH; VM1 desktop)
7. [ ] Статические IP (netplan)
8. [ ] VM1: ssh-keygen; публичный ключ на VM2-VM4
9. [ ] VM2: apt install ntp → time.belgim.by + ntp1/2/3.vniiftri.ru; ufw: ssh, ntp, icmp
10. [ ] VM3: docker; NextChat; nginx + self-signed cert; ufw: ssh, icmp, 80,443 (from VM1)
11. [ ] VM4: docker (интернет после установки закрыт); образ vLLM и веса Qwen2.5-1.5B-Instruct доставить с VM1 (docker save/load + scp); ufw: ssh, icmp, 8000 from VM3
12. [ ] VM3 → vLLM (http://192.168.100.14:8000/v1)
13. [ ] NTP: VM1/VM3/VM4 → 192.168.100.12
14. [ ] Проверки: ntpq -p, timedatectl, curl -k https://192.168.100.13, чат, ufw status

## Правила файрвола (ufw)

- VM2: allow OpenSSH; allow 123/udp; allow icmp
- VM3: allow OpenSSH; allow icmp; allow from 192.168.100.11 to any port 80,443 proto tcp
- VM4: allow OpenSSH; allow icmp; allow from 192.168.100.13 to any port 8000 proto tcp

## Доставка модели на VM4 (по заданию)

На VM4 интернет считается закрытым после установки docker:
- VM1: docker pull vllm/vllm-openai:latest → docker save → tar
- VM1: скачатьWeights Qwen2.5-1.5B-Instruct (HuggingFace, ~3GB)
- scp на VM4 → docker load; ufw deny outgoing
- vLLM: --model /models/Qwen2.5-1.5B-Instruct --host 0.0.0.0 --port 8000
