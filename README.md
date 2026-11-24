# Стенд из 4 VM: NTP + веб-интерфейс ИИ (NextChat) + vLLM (Qwen2.5)

Тестовое задание: лабораторный стенд из 4 виртуальных машин Hyper-V,
полностью разворачиваемый скриптами. Ubuntu 24.04, сеть 192.168.100.0/24
(Internal switch + NAT на хосте Windows 11).

## Архитектура

```
Хост Windows 11 + Hyper-V
 └─ LabSwitch (Internal) 192.168.100.0/24, хост 192.168.100.1 (WinNAT)
     ├─ VM1 192.168.100.11  Ubuntu Desktop 24.04 — рабочая станция
     │                        (браузер -> NextChat, источник артефактов для VM4)
     ├─ VM2 192.168.100.12  Ubuntu Server 24.04 — NTP-сервер (ntpsec/ntpd)
     │                        time.belgim.by + ntp1/2/3.vniiftri.ru
     ├─ VM3 192.168.100.13  Ubuntu Server 24.04 — веб-фронт: NextChat (docker)
     │                        за nginx с self-signed TLS; 80->443->3000
     └─ VM4 192.168.100.14  Ubuntu Server 24.04 — vLLM (docker, CPU)
                              Qwen2.5-1.5B-Instruct; интернет закрыт после
                              установки docker (ufw outgoing deny)
```

Поток запроса: **браузер VM1 → https://192.168.100.13 (nginx, self-signed)
→ NextChat → http://192.168.100.14:8000/v1 (vLLM) → ответ модели**.

## Что внутри

| Путь | Назначение |
|------|-------------|
| `PLAN.md` | исходный план/архитектура |
| `PROGRESS.md` | журнал выполнения: что сделано по дням, грабли и решения |
| `scripts/` | все скрипты настройки, пронумерованы по порядку применения |

Скрипты выполняются на хосте (PowerShell, **админ**):
- `0-setup-network-host.ps1` — LabSwitch + vNIC хоста 192.168.100.1 + WinNAT
- `1-create-vms.ps1` — создание 4 VM (Gen2/UEFI, static memory)

Установка Ubuntu на VM — интерактивно с ISO (шаги задокументированы в
PROGRESS.md: static IP, без LVM, OpenSSH server; для установщика нужно
>= 2 GB RAM).

Скрипты конфигурации гоняются по SSH с VM1 (или хоста) как
`ssh -t admin1@IP "sudo bash NN-*.sh"`:
- `05-vm1-docker.sh` — docker на VM1
- `10-vm2-ntp.sh` — NTP-сервер на VM2 (ntpsec, см. «Отклонения»)
- `11-ntp-clients.sh` — NTP-клиенты VM1/VM3/VM4 → 192.168.100.12
- `20-vm3-web.sh` — VM3: docker, NextChat, nginx + self-signed cert, ufw
- `30-vm4-prepare.sh` — VM4: docker (последний шаг с интернетом)
- `31-vm1-download-artifacts.sh` — VM1: образ vLLM (docker pull/save) +
  веса Qwen2.5-1.5B-Instruct с HuggingFace
- `32-vm4-offline-install.sh` — VM4 офлайн: docker load, запуск vLLM, ufw
- `33-vm4-docker-user-fw.sh` — VM4: изоляция порта 8000 через DOCKER-USER
  (docker publish обходит ufw; скрипт ставится как systemd-юнит)
- `40-verify.sh` — полный прогон проверок со стендом
- `vm1-bootstrap.sh` — переиспользуемая часть настройки VM1 (netplan и пр.)

## Файрволы (ufw)

- VM2: `OpenSSH`, `123/udp` (NTP)
- VM3: `OpenSSH`; `80,443/tcp` **только от 192.168.100.11**
- VM4: `OpenSSH`; `8000/tcp` **только от 192.168.100.13**; исходящий трафик
  — только `22/tcp` и подсеть лаборатории (интернет закрыт по заданию);
  **плюс** правила в цепочке `DOCKER-USER` (см. «Отклонения» п.2)

## Верификация

`40-verify.sh` (с VM1) проверяет по цепочке:
1. NTP-клиенты синхронизированы с 192.168.100.12
2. VM2: `ntpq -p` — избранный time.belgim.by + 3 vniiftri; ufw
3. VM3: `curl -k https://127.0.0.1` = 200; nextchat Up; ufw
4. VM4: vllm Up; ufw
5. Изоляция: VM1 → 192.168.100.14:8000 — таймаут (порт только для VM3)
6. Инференс VM3 → vLLM: ответ модели по OpenAI-протоколу

Финальная пользовательская проверка: браузер VM1 → https://192.168.100.13
(принять self-signed сертификат) → модель Qwen2.5-1.5B-Instruct отвечает
в веб-чате NextChat.

## Отклонения от буквы ТЗ и почему

1. **NTP: пакет `ntp` заменён на `ntpsec`.** В Ubuntu 24.04 (noble) пакет
   `ntp` отсутствует в репозиториях. `ntpsec` — прямой потомок классического
   `ntpd` (тот же демон и конфигурация), т.е. задание «сервер NTP, НЕ chrony»
   выполнено: это ntpd, а не chrony.
2. **Изоляция порта 8000 на VM4: ufw + DOCKER-USER.** Опубликованный docker
   порт (`-p 8000:8000`) идёт через DNAT в цепочке `DOCKER` (FORWARD) и
   ufw (INPUT) на него не действует. Требование «8000 только с VM3» поэтому
   enforced в цепочке `DOCKER-USER` (ACCEPT от .13, DROP остальным),
   переживает рестарты docker и ребут (systemd-юнит
   `vm4-docker-user-fw.service`).
3. **vLLM: образ `vllm/vllm-openai-cpu:v0.34.0`.** В ТЗ тег не фиксирован.
   v0.16.0 падал на хосте с SIGILL (собран под AVX-512; CPU стенда — Zen 3,
   только AVX2). С v0.17.0 у vLLM раздельные ядра под AVX2/AVX-512, v0.34.0
   работает. На 8 GB RAM необходимы `VLLM_CPU_KVCACHE_SPACE=1` и
   `--enforce-eager`.
4. **Qwen скачивается с HuggingFace с репо `Qwen/Qwen2.5-1.5B-Instruct`**
   (с префиксом организации), на диске и в vLLM — короткое имя
   `Qwen2.5-1.5B-Instruct`, как ждёт NextChat.

## Окружение

Хост: Windows 11 Enterprise, Hyper-V, AMD Ryzen 7 7435HS (Zen 3, AVX2),
32 GB RAM. Гостям суммарно 15 GB. ISO (server 24.04.5, desktop 24.04.5.1)
и VHDX в git не входят.
