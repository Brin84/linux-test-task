# VM-Lab: журнал выполнения тестового задания (обновлено 2026-11-20)

## Задание (кратко)

4 Hyper-V VM на E:\\vm-lab, сеть 192.168.100.0/24 (Internal LabSwitch + NAT на хосте 192.168.100.1):

* VM1 (.11) Ubuntu Desktop 24.04 — рабочая станция, с неё настраивается всё остальное
* VM2 (.12) Ubuntu Server — NTP-сервер (пакет ntp, НЕ chrony), серверы time.belgim.by +
ntp1/ntp2/ntp3.vniiftri.ru; ufw: ntp, icmp, ssh
* VM3 (.13) Ubuntu Server — веб-интерфейс ИИ (NextChat в docker), nginx + самоподписанный
сертификат (HTTPS), ufw: icmp, ssh, http, https — доступ с VM1
* VM4 (.14) Ubuntu Server — vLLM в docker (Qwen2.5-1.5B-Instruct), образ и модель доставляются
через VM1 (интернет VM4 закрыт после установки docker), ufw: icmp, ssh, порт 8000 для VM3

## Что сделано

1. Сеть хоста: LabSwitch (Internal), vNIC хоста 192.168.100.1, NetNat "LabNAT" — скрипт
scripts\\0-setup-network-host.ps1 выполнен, всё \[OK].
2. VM1–VM4 созданы (Gen2, UEFI), VHDX на E:\\vm-lab\\vms<имя>\\ — scripts\\1-create-vms.ps1.
3. VM2/VM3/VM4 настроены (CPU 1/2/4, RAM 1/2/8 GB, secure boot MicrosoftUEFICertificateAuthority,
DVD с ubuntu-24.04.5-live-server-amd64.iso, boot с DVD, чекпойнты off). Проверено Get-VM.
4. ISO: ubuntu-24.04.5-live-server-amd64.iso (3.8 GB) готов; мусорные 24.04.3 ISO удалены.
5. Desktop ISO (ubuntu-24.04.5.1-desktop-amd64.iso, 5.8 GB) качался curl -A 'Mozilla/5.0'.
ПОСЛЕ ДОКАЧКИ: проверить размер (\~5.8 GB), прогнать доводка-блок (настроит VM1: 2 CPU/4GB).

## Текущая проблема: установка Ubuntu Server на VM2

* Попытка 1: ошибка установщика ("Sorry, there was a problem completing the installation").
* Попытка 2: дошёл до формы профиля, но клавиатура в окне VM не работает (даже после щелчка
мышью внутрь окна).
* План: проверить, жив ли интерфейс (мигает ли курсор, реагирует ли подсветка на стрелки/Tab).
Если мёртв — Stop-VM/Start-VM и новая попытка, в шаге Storage СНЯТЬ галочку
"Set up this disk as an LVM group" (без LVM). Если жив — переподключить vmconnect,
попробовать Enhanced session.

## Шаги установки Ubuntu Server (VM2/VM3/VM4)

1. Language: English; Keyboard: default
2. Ubuntu Server; third-party drivers: Skip
3. Network: интерфейс -> Edit -> IPv4 Manual: Subnet 192.168.100.0/24, Address .12/.13/.14,
Gateway 192.168.100.1, DNS 8.8.8.8,1.1.1.1
4. Proxy: пусто; Mirror: default
5. Storage: Use an entire disk; БЕЗ галочки LVM
6. Profile: Your name admin / Server name vm2|vm3|vm4 / Username admin / пароль (один на все VM)
7. Ubuntu Pro: Skip
8. SSH: ОТМЕТИТЬ "Install OpenSSH server"
9. Snaps: ничего; после "\[OK] Installed!" -> Reboot Now
10. Если экран просит "detach medium" — Enter, либо Stop-VM/Start-VM (загрузится с диска).

## Грабли (важно помнить)

* Claude-инструменты (Bash/PowerShell/Write) периодически блокируются сбоем классификатора
("claude-sonnet-5 temporarily unavailable") — тогда команды выполняет пользователь в
админ-PowerShell и присылает вывод.
* Hyper-V: Set-VMFirmware / Add-VMDvdDrive / Get-VMDvdDrive / Set-VMDvdDrive принимают
-VMName (НЕ -Name); Set-VM / Get-VM — обычный -Name; Set-VMKeyProtector не существует
на клиентском Hyper-V Win11.
* New-VM: -VHDPath и -NewVHDPath взаимоисключающие.
* 24.04.3 ISO удалены с зеркала (403); рабочие: 24.04.5 server, 24.04.5.1 desktop;
curl требует -A 'Mozilla/5.0' (иначе 403 от releases.ubuntu.com).
* Hyper-V-команды требуют АДМИН-PowerShell (иначе VirtualizationException на Get-VM).
* Крестик vmconnect НЕ выключает VM (только окно); выключение — Stop-VM.
* В vmconnect: щёлкнуть мышью внутрь окна для захвата клавиатуры; есть Basic/Enhanced session.

## Доводка-блок VM (проверенный, идемпотентный; запускать в админ-PowerShell)

$ErrorActionPreference = "Stop"
$labDir = "E:\\vm-lab"
$isoServer  = "$labDir\\iso\\ubuntu-24.04.5-live-server-amd64.iso"
$isoDesktop = "$labDir\\iso\\ubuntu-24.04.5.1-desktop-amd64.iso"
$configs = @(
@{ Name = "VM1"; Iso = $isoDesktop; Cpu = 2; RamGB = 4 },
@{ Name = "VM2"; Iso = $isoServer;  Cpu = 1; RamGB = 1 },
@{ Name = "VM3"; Iso = $isoServer;  Cpu = 2; RamGB = 2 },
@{ Name = "VM4"; Iso = $isoServer;  Cpu = 4; RamGB = 8 }
)
foreach ($v in $configs) {
if (-not (Test-Path $v.Iso)) { Write-Host "\[FAIL] ISO not found: $($v.Iso)"; continue }
Set-VM -Name $v.Name -ProcessorCount $v.Cpu -StaticMemory -MemoryStartupBytes ($v.RamGB \* 1GB)
Set-VMFirmware -VMName $v.Name -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
Get-VMDvdDrive -VMName $v.Name | Remove-VMDvdDrive
Add-VMDvdDrive -VMName $v.Name -Path $v.Iso
Set-VMFirmware -VMName $v.Name -FirstBootDevice (Get-VMDvdDrive -VMName $v.Name)
Set-VM -Name $v.Name -AutomaticCheckpointsEnabled $false -CheckpointType Disabled
Write-Host "\[OK] $($v.Name)"
}
Get-VM | Format-Table Name, State, ProcessorCount, MemoryAssigned

## План дальше (по порядку)

1. Добить установку VM2.
2. После загрузки VM2: ip a; ping -c3 192.168.100.1; ping -c3 8.8.8.8; ping -c3 ya.ru
3. Проверить desktop-ISO, прогнать доводка-блок (настроит VM1).
4. Поставить VM3 (.13), VM4 (.14) — те же шаги установки.
5. Поставить Ubuntu Desktop на VM1 (.11).
6. С VM1: ssh-keygen, ssh-copy-id на VM2–VM4; вся дальнейшая настройка — с VM1 по SSH.
7. VM2: bash 10-vm2-ntp.sh (пакет ntp, /etc/ntp.conf: time.belgim.by iburst prefer +
ntp1/ntp2/ntp3.vniiftri.ru; ufw: default deny, OpenSSH, 123/udp; tz Europe/Minsk).
8. VM1/VM3/VM4: bash 11-ntp-clients.sh (timesyncd -> NTP=192.168.100.12).
9. VM3: bash 20-vm3-web.sh (docker, NextChat 127.0.0.1:3000, BASE\_URL=http://192.168.100.14:8000,
nginx 80->443 self-signed CN=vm3.lab.local, ufw: ssh + 80,443 с 192.168.100.11).
10. VM4: bash 30-vm4-prepare.sh (docker, последний шаг с интернетом); на VM1:
bash 31-vm1-download-artifacts.sh (docker pull vllm/vllm-openai, docker save; модель
Qwen2.5-1.5B-Instruct); scp на VM4; на VM4: bash 32-vm4-offline-install.sh
(docker load, vLLM 0.0.0.0:8000, ufw; В СКРИПТЕ 32 ЕСТЬ МУСОРНАЯ БИТАЯ СТРОКА docker run —
ПОЧИСТИТЬ ПЕРЕД ЗАПУСКОМ).
11. Финал: bash 40-verify.sh с VM1; браузер VM1 -> https://192.168.100.13 (принять
самоподписанный сертификат), модель Qwen2.5-1.5B-Instruct.

## Файлы

* E:\\vm-lab\\PLAN.md — архитектура
* E:\\vm-lab\\scripts\\0-setup-network-host.ps1 — сеть хоста (выполнен)
* E:\\vm-lab\\scripts\\1-create-vms.ps1 — создание VM (выполнен)
* E:\\vm-lab\\scripts\\2-get-isos.ps1 — УСТАРЕЛ, не использовать
* E:\\vm-lab\\scripts\\1{0,1,2,3}-... .sh — конфигурация VM (ещё не выполнялись):
10-vm2-ntp.sh, 11-ntp-clients.sh, 20-vm3-web.sh, 30-vm4-prepare.sh,
31-vm1-download-artifacts.sh, 32-vm4-offline-install.sh, 40-verify.sh
* E:\\vm-lab\\iso\\ — образы; E:\\vm-lab\\vms<имя>\\ — VHDX



\---

\## Обновление, вечер 2026-11-20 (конец рабочего дня)



Третья попытка установки VM2 тоже упала: "An error occurred during installation".

Причина из отчёта НЕ вытащена. Клавиатура в окне VM2 в этот раз работала (форму заполняли).



Статус остального: VM2/VM3/VM4 настроены на хосте; VM1 ждёт desktop-ISO (качался,

размер НЕ проверен — проверить \~5.8 GB и прогнать доводка-блок); сетка хоста OK.



\### Перед уходом

\- Выключить VM2: Stop-VM -Name VM2 -TurnOff -Force (в админ-PowerShell)



\### План на завтра

1\. Get-ChildItem 'E:\\vm-lab\\iso' — размер desktop-ISO (\~5.8 GB?); если ок — доводка-блок.

2\. Диагностика ошибки VM2 (обязательно ДО новой попытки):

&#x20;  а) на экране ошибки: \[View full report] -> End -> переписать последние 5–10 строк;

&#x20;  б) Ctrl+Alt+F2 (консоль live-установщика): ip a; ping -c3 192.168.100.1;

&#x20;     ping -c3 8.8.8.8; ping -c3 archive.ubuntu.com  (назад в установщик — Ctrl+Alt+F1);

&#x20;  в) исходя из вывода: не работает NAT / DNS / зеркало — чинить соответствующее.

3\. Новая попытка установки VM2, в шаге Storage СНЯТЬ галочку "Set up this disk as an LVM group".

4\. Далее — по общему плану выше (VM3, VM4, VM1, SSH-ключи, роли).







---

## Обновление 2026-11-20 (вечер): VM2 ГОТОВА

Причина трёх падений: curtin block-meta (configuring partition-0) — LVM на
грязном VHDX от неудачных попыток + 1 GB RAM мало. НЕ сеть (NAT/DNS проверены, OK).
Лечение (с первого раза): чистый VHDX + 2 GB RAM + снять галочку LVM.

Сделано: desktop-ISO докачан (5.82 GB); доводка-блок прогнан; VM2 установлена
(Ubuntu 24.04.5, eth0=192.168.100.12/24, SSH True с хоста, ping 8.8.8.8/ya.ru OK).
Пинг 192.168.100.1 с VM2 не отвечает — норма (брандмауэр Windows молчит на ICMP,
профиль Public); NAT рабочий. Username на всех VM = admin1.
Скрипты 20/31/32 переписаны начисто (LF, UTF-8 no BOM, ASCII-комменты): в 32
убита битая docker run, ART=/home/admin1, запуск через sudo; в 31 образ
vllm/vllm-openai:cpu (GPU нет, :latest требует CUDA); в 20 добавлен OPENAI_API_KEY.

Грабли: Remove-VMHardDiskDrive не принимает -Path; удалять VHDX можно не
отцепляя диск — VM подхватит новый по тому же пути (Add-VMDrive тогда лишний).
PS 5.1 Get-Content/Set-Content портит UTF-8 — перезаписывать только
[System.IO.File]::WriteAllText + LF. RAM для установщика нужно >= 2 GB.

План: VM3 (.13), VM4 (.14) — тот же recipe; VM1 Desktop (.11); ssh-copy-id с VM1;
10 -> 11 -> 20 -> 30 -> 31 -> scp -> sudo 32 -> 40-verify.sh.

---

## Обновление 2026-11-21 (вечер): VM2/VM3/VM4 готовы, NTP работает. Стоп на сегодня.

СДЕЛАНО:
- VM3 (.13) и VM4 (.14) установлены (рецепт VM2; VM3 осталась С LVM - ничего
  не сломало). Все серверы: NAT/DNS работают, кросс-пинги VM4->VM2/VM3 0% потерь,
  SSH с хоста True.
- C: было 5.8 GB свободно -> powercfg /h off -> 18.5 GB. ХИБЕРНАЦИЯ ВЫКЛЮЧЕНА
  (возврат: powercfg /h on).
- NTP на VM2 РАБОТАЕТ: *time.belgim.by + 3 vniiftri (+). В noble пакета ntp нет
  -> ставится ntpsec (тот же ntpd, НЕ chrony; задание соблюдено). Конфиг
  /etc/ntpsec/ntp.conf, сервис ntpsec; перед установкой purge systemd-timesyncd
  (конфликт time-daemon). Скрипт 10 переписан под это.
- Скрипты 10/20/31/32 переписаны начисто: ASCII-комменты, LF, UTF-8 no BOM.
  31/32: образ vllm/vllm-openai:cpu (GPU нет, :latest не стартует без CUDA);
  32: ART=/home/admin1 + sudo bash; 20: добавлен OPENAI_API_KEY.

ГРАБЛИ:
- SSH-пароль из PS не вводился из-за РАСКЛАДКИ (русская вместо EN) - сверять в
  блокноте, вставка правым кликом.
- ssh host "...sudo..." требует -t (нужен терминал для sudo).
- Конфиг VM на клиентском Win11 не переносится на другой диск: параметра
  -ConfigurationStoragePath нет, WMI ModifySystemSettings(ConfigurationDataRoot)
  = 32773. Конфиги остались на C: (18.5 GB >= 16 GB VMRS - ок).
- ntp в noble: конфликт ntpsec <-> systemd-timesyncd, нужен purge второго.
- RAM хоста НЕ ИЗВЕСТНА. Узнать завтра первой командой:
  [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize/1MB,1)
  Гостям нужно 16 GB всего; если хост 16 GB - урезать VM4 до 6 GB.

СТАТУС: VM1 Desktop НЕ установлен; VM2 NTP ГОТОВ; VM3/VM4 ОС+SSH готовы.

ПЛАН НА ЗАВТРА:
1. SSH-ключ хоста -> authorized_keys на .12/.13/.14 (команды в чате 21.11).
2. Узнать RAM хоста (см. грабли).
3. Ubuntu Desktop на VM1: Stop-VM VM2 VM3 VM4 -TurnOff; Start-VM VM1; vmconnect.
   English -> Install Ubuntu (Normal) -> Network IPv4 Manual 192.168.100.11/24
   gw 192.168.100.1 DNS 8.8.8.8 -> admin1 -> Reboot.
4. Раскатка по SSH (scp скриптов + ssh -t sudo bash): 20 на VM3, 30 на VM4,
   11 на VM1/VM3/VM4, 31 на VM1, scp артефактов на VM4, sudo 32 на VM4.
5. Финал: 40-verify.sh; браузер VM1 -> https://192.168.100.13.

---

## Обновление 2026-11-22 (ночь): VM1 установлена, стенд почти собран

СДЕЛАНО:
- КЛАССИФИКАТОР Claude Code более НЕ блокирует инструменты. Корень: шлюз
  omniroute (localhost:20128) не знал, куда слать bare-модель классификатора
  claude-sonnet-5 (401 openrouter). Починен model-alias в omniroute:
  claude-sonnet-5 -> cinf/claude-sonnet-5 (+ haiku-алиасы). Если «classifier
  unavailable» вернётся - смотреть Request Log дашборда omniroute и
  GET /api/settings/model-aliases.
- SSH-ключ хоста раздан на .11/.12/.13/.14 (раздача через cat pub | ssh
  "tr -d '\r' >> authorized_keys && sort -u"; tr от CRLF ОБЯЗАТЕЛЕН). Вход без
  пароля работает; NOPASSWD-sudo включён на всех 4 VM
  (/etc/sudoers.d/admin1-nopasswd, chmod 440).
- RAM хоста 31.8 GB - урезать RAM VM4 НЕ нужно.
- VM1 ОКАЗАЛАСЬ НЕ УСТАНОВЛЕННОЙ: прошлая «установка» = live-сессия с DVD
  (/cow, /rofs, casper, юзер ubuntu, диска нет вовсе). 2 GB /cow кончались ->
  «no space left on device». Лечено: создан диск New-VHD 40GB ->
  Add-VMHardDiskDrive -> установка Desktop с ISO по-настоящему (Interactive,
  Default selection, Erase disk, admin1/vm1, без third-party). После ребута
  была загрузка в PXE (ISO вынут, диск пуст - установка тогда не запускалась);
  ISO вернули, прогнали установщик до «Installation complete».
- VM1 настроена: hostname vm1, static 192.168.100.11/24 gw .1 DNS 8.8.8.8
  ПЕРМАНЕНТНО через netplan (renderer: NetworkManager!) - скрипт
  scripts/vm1-bootstrap.sh (менять сеть ПОСЛЕДНИМ шагом, моргает ssh);
  ssh+ssh.socket в autostart; openssh-server поставлен; docker 29.10 установлен
  (scripts/05-vm1-docker.sh); admin1 в группе docker.
- NTP-клиенты (scripts/11) на vm1/vm3/vm4: ServerAddress=192.168.100.12, все
  синхронизированы (ServerAddress виден в timedatectl show-timesync).
- VM3 (scripts/20) ГОТОВА: docker + NextChat (контейнер nextchat, Up,
  127.0.0.1:3000) + self-signed сертификат + nginx (80->301->443, 443->3000),
  ufw: 80/443 только с 192.168.100.11. curl -k https://127.0.0.1 = 200.
- VM4 (scripts/30): docker 29.10 установлен, активен.
- Перенос VM1->VM4 подготовлен: на VM1 создан свой ed25519, публик добавлен в
  authorized_keys VM4, тест VM1->VM4 без пароля OK (known_hosts принят через
  accept-new).
- Артефакты для VM4 на VM1: образ vllm/vllm-openai-cpu:v0.16.0 скачан
  (4.5 GB) и сохранён в ~/vm4-artifacts/vllm-openai.tar; веса Qwen
  догружаются (см. ГРАБЛИ про hf).

ИЗМЕНЕНИЯ СКРИПТОВ (важно!):
- Тег vllm/vllm-openai:cpu УДАЛЁН из Docker Hub (cpu-тегов нет вообще).
  CPU-образы теперь в отдельном репо: vllm/vllm-openai-cpu (взят v0.16.0).
  31 и 32 обновлены.
- 31: HF-репо модели = Qwen/Qwen2.5-1.5B-Instruct (с префиксом организации!);
  на диске и в vLLM короткое имя Qwen2.5-1.5B-Instruct (NEXTCHAT ждёт его).
  pip в noble требует --break-system-packages.
- 1-create-vms.ps1 сохранился в cp1251 (Read/Write его портят) - править
  только кодосберегающими средствами.

ГРАБЛИ:
- Windows OpenSSH scp: без -O падает («subsystem request failed» - на VM1 нет
  sftp-сервера до установки openssh-sftp-server), с -O работает. После scp
  ВСЕГДА sed -i 's/\r$//' (CRLF ломает и bash: «dockе.service does not exist»).
- Кавычки PS 5.1 -> ssh -> bash ломаются на вложенных ''; сложные команды
  записывать файлом-обёрткой (tmp-*.sh) и гонять bash ~/tmp-*.sh.
- После переустановки гостя: ssh-keygen -R IP (REMOTE HOST IDENTIFICATION HAS
  CHANGED).
- Docker на десктопе после установки НЕ enabled автоматически в нашем скрипте
  из-за CRLF; enable вручную.
- ssh-сервер Ubuntu 24.04 desktop: systemctl is-active ssh = inactive при
  работающем ssh.socket (порт 22 открыт, это норма).

СТАТУС СЕЙЧАС: VM2 NTP готов; VM3 web готова; VM4 docker готов (ждёт vLLM);
VM1 готова, качает веса Qwen (~3 GB) в ~/vm4-artifacts/model.

ДОДЕЛАТЬ (по порядку):
1. Дождаться весов -> с VM1: scp ~/vm4-artifacts/vllm-openai.tar и model/ на
   admin1@192.168.100.14:~/ (по ключу, без пароля).
2. scp 32-vm4-offline-install.sh на VM4; sudo bash 32 (docker load, /opt/models,
   запуск vllm/vllm-openai-cpu:v0.16.0, ufw: 8000 только VM3 + outgoing deny
   192.168.100.0/24-only - закрытие интернета по заданию).
3. Ждать загрузки модели (CPU, первая - минуты): curl VM3->VM4:8000/v1/models.
4. 40-verify.sh с VM1.
5. Браузер VM1 -> https://192.168.100.13 (self-signed -> Advanced/Proceed),
   модель Qwen2.5-1.5B-Instruct, API key любой (sk-lab-local), проверить чат.
6. Прибить tmp-*.sh в scripts/ (одноразовые).
---

## Обновление 2026-11-23 (вечер): vLLM ЗАПУЩЕН на VM4, отвечает генерацией

СДЕЛАНО:
- Хост перезагружался -> VM были Off; подняты VM1+VM4 (VM2/VM3 ждут старта).
- Артефакты (образ v0.16.0 tar 1.0 GB + модель 2.9 GB) перенесены VM1->VM4
  (~/vm4-incoming/), полная сверка: md5 tar + 33 файла модели идентичны.
- КОРЕНЬ ПАДЕНИЯ vLLM (exit 132, Restarting loop): образ v0.16.0 скомпилирован
  с AVX-512, а хост Ryzen 7 7435HS (Zen 3) = только AVX2. dmesg: 'traps:
  vllm trap invalid opcode in _C.abi3.so'. Совпадает с upstream issues
  vllm#32554/#36898. Лечение: НОВАЯ ВЕРСИЯ ОБРАЗА - с v0.17.0 vLLM имеет
  раздельные ядра _C_AVX2/_C_AVX512 (vllm/platforms/cpu.py: import_kernels).
- На VM1 проверено: v0.34.0 импорт/инспект модели ОК (SIGILL ушёл); полный
  тест упал лишь по RAM (4 GB < модель+KV+компиляция) - на VM4 8 GB хватило.
- НО на VM4 v0.34.0 без restrict падал OOM (worker 7.7 GB > 8 GB всего,
  dmesg oom-kill, 2 рестарта). Рабочая конфигурация контейнера vllm:
  --shm-size=1g -e VLLM_CPU_KVCACHE_SPACE=1 ... --enforce-eager
  (eager отключает индуктор-компиляцию: она жгла RAM и 15 мин CPU).
- vLLM v0.34.0: РАБОТАЕТ на VM4: /v1/models = Qwen2.5-1.5B-Instruct,
  chat/completions отвечает (тест 'Скажи OK' -> 'OK'). KV 37k токенов.
- Скрипт 32 обновлён: тег v0.34.0, dockеr load из vllm-cpu-v034.tar.gz
  (fallback на старый tar), идемпотентное mv модели (бэкап .bak).

ГРАБЛИ (новые):
- curl 127.0.0.1:8000 НА ХОСТЕ VM4 виснет (DNAT-петля docker+ufw:
  lo-трафик редиректится в контейнер, ответ теряется) - НОРМА, не чинить;
  рабочие пути: изнутри контейнера и ЛЮБОЙ ethernet-IP VM4 (192.168.100.14).
  VM3 подключается по 192.168.100.14 - на это DNAT не влияет.
- docker exec vllm ... - рабочий способ дергать API локально на VM4.
- OOM на VM4 (8 GB): модель bf16 2.9 GB + KV 2 GB + компиляция > RAM.
  Обязательно VLLM_CPU_KVCACHE_SPACE=1 и --enforce-eager.
- Тесты 'docker run --rm vllm...' НЕ работают как ожидалось: у образа
  ENTRYPOINT = vllm-сервер, bash-аргументы игнорируются -> SIGILL в тестах
  был от entrypoint, а не от bash. Нужен --entrypoint bash/python.
- Docker Hub API: у vllm/vllm-openai-cpu НЕТ avx2-тегов (PR 36901 не смержен);
  page=2 tags API возвращает 0 - пагинация кривая, юзать ?name=.
- scp с VM1: nohup scp ... & умирает при закрытии ssh-сессии, если не
  позаботиться о фоновом режиме ДО (nohup sh -c '... &' обёртка работает).
- mkdir ~/vm4-incoming на VM4 НУЖЕН ДО scp (scp не создаёт каталоги).

СТАТУС: VM4 vLLM ГОТОВ (v0.34.0, eager, KV 1 GB). VM1/VM2/VM3: VM1 готова;
VM2/VM3 выключены (нужен Start-VM).

ДОДЕЛАТЬ:
1. Start-VM VM2, VM3 (админ-PS). SSH на VM2/VM3 - проверить NTP после
   простоя (ntpq -p на VM2; timedatectl на VM1/VM3/VM4).
2. curl с VM3: http://192.168.100.14:8000/v1/models (ufw: 8000 от .13 - ок).
3. Проверить NextChat на VM3 (docker ps; curl -k https://127.0.0.1 = 200),
  🏰 BASE_URL в NextChat должен указывать на http://192.168.100.14:8000/v1
   (проверить env контейнера!).
4. 40-verify.sh с VM1.
5. Браузер VM1 -> https://192.168.100.13 (self-signed -> Advanced/Proceed),
   модель Qwen2.5-1.5B-Instruct, API key sk-lab-local, проверить чат.
6. Прибить tmp-*.sh в scripts/ (одноразовые); обновить PLAN.md если нужно.

---

## Обновление 2026-11-23 (поздний вечер): СТЕНД ПОЛНОСТЬЮ СОБРАН И ПРОВЕРЕН

СДЕЛАНО:
- VM2/VM3 подняты после простоя; NTP самовосстановился (таймауты клиентов
  были от выключенной VM2): VM1/VM3/VM4 synchronized с 192.168.100.12.
- 40-verify.sh прогнан с VM1 дважды (вторая версия с sudo для ufw/docker
  на VM2/VM3/VM4). ВСЁ ЗЕЛЁНОЕ:
  1) NTP клиенты synchronized; 2) VM2: ntpq *time.belgim.by + 3 vniiftri,
  ufw 123/udp+ssh; 3) VM3 HTTPS 200 (self-signed), nextchat Up,
  ufw 80/443 от VM1; 4) VM4 vLLM API отвечает, ufw 8000 от VM3;
  5) VM1->VM4:8000 = таймаут (изоляция работает); 6) VM3->VM4 инференс:
  'Привет! Как я могу помочь вам сегодня?' (finish_reason stop).
- NextChat env проверен: BASE_URL=http://192.168.100.14:8000,
  OPENAI_API_KEY=sk-lab-local.

СТАТУС: ВСЁ ЗАДАНИЕ ВЫПОЛНЕНО на уровне скриптовых проверок.

ОСТАЛАСЬ ПОЛЬЗОВАТЕЛЬСКАЯ ПРОВЕРКА (руками, из GUI VM1):
- Браузер VM1 -> https://192.168.100.13 -> Advanced/Proceed (self-signed),
  модель Qwen2.5-1.5B-Instruct, ключ sk-lab-local -> отправить сообщение,
  убедиться, что LLM отвечает в веб-интерфейсе NextChat.

ПОСЛЕ ПРОВЕРКИ (гигиена):
- Прибить tmp-*.sh в scripts/ (одноразовые) и мусор на VM:
  VM1: ~/scp-*.log, ~/scp-*.flag, ~/m1-list.txt, /tmp/vllm*.log;
  VM4: ~/vm4-incoming (3.9 GB - можно удалить после стабильной работы),
  ~/m4-list.txt, старый vllm-openai.tar (v0.16.0 - образ больше не нужен),
  docker image vllm/vllm-openai-cpu:latest и :v0.16.0 (v1.0 доступен на VM1).
- VM1 диск 31G/39G занят: ~/vm4-artifacts (4.6 GB) можно почистить
  после приёмки стенда.

---

## Обновление 2026-11-24 (день): стенд поднят, найдена и закрыта ДЫРА в изоляции VM4

СДЕЛАНО:
- Все 4 VM подняты после простоя (были Off). SSH, NTP, NextChat, vLLM живы.
- НАЙДЕНА РЕАЛЬНАЯ ДЫРА: VM1 -> VM4:8000 возвращала 200 (изоляция НЕ
  работала!). Причина: docker публикует порт через свою цепочку DOCKER в
  FORWARD (DNAT в обход ufw/INPUT). Правило ufw "8000 от VM3" на
  docker-published порт НЕ действует. Прогон 23.11, видимо, попал в окно,
  когда цепочка ещё не была пересоздана рестартом docker. По заданию порт
  8000 должен быть доступен ТОЛЬКО с VM3.
- Лечение: цепочка DOCKER-USER (была пустая) — ACCEPT dpt:8000 от
  192.168.100.13, затем DROP dpt:8000 всем остальным. Проверено:
  VM1 -> VM4:8000 = timeout (exit 28), VM3 -> VM4:8000 = 200, инференс
  "работает?" -> "да" (finish_reason stop).
- Закреплено переживать рестарт docker/ребут: скрипт
  scripts/33-vm4-docker-user-fw.sh (самоочищающийся: вычищает ВСЕ строки с
  dpt:8000 из DOCKER-USER по номерам строк, затем вставляет заново; ждёт
  появления цепочки DOCKER до 30 сек) + systemd-юнит
  /etc/systemd/system/vm4-docker-user-fw.service на VM4 (oneshot,
  After+PartOf docker.service, enabled; скрипт в
  /usr/local/sbin/vm4-docker-user-fw.sh). Рестарт docker пережит, дублей
  правил нет.
- NTP: VM2 ntpq *srvbgimpod01.be (time.belgim.by) + 3 vniiftri, reach 377.
  VM3 после простоя была "not synchronized" (timesyncd poll = 34 мин,
  ждёт следующего опроса) — лечится systemctl restart
  systemd-timesyncd; после него synchronized=yes на VM1/VM3/VM4.
- NextChat env: BASE_URL=http://192.168.100.14:8000, ключ на месте
  (проверен с sed-маскировкой, в лог не выводился).

ГРАБЛИ (новые):
- Docker published port (-p 8000:8000) ОБХОДИТ ufw — фильтровать только
  через DOCKER-USER. ufw на VM4 по-прежнему нужен для остальных правил
  (outgoing deny и пр.).
- Классификатор Claude блокирует вывод значений env с API_KEY в лог —
  проверять с sed-маскировкой.
- iptables -D с -m comment требует ТОЧНОЕ совпадение текста комментария;
  надёжнее чистить правила по номерам строк (--line-numbers + awk).
- timesyncd после простоя "not synchronized" до следующего poll — не
  поломка; форсить restart systemd-timesyncd.

СТАТУС: стенд РАБОЧИЙ и изолированный (проверено 24.11 после простоя и
после рестарта docker). Осталась пользовательская проверка в GUI VM1
(браузер -> https://192.168.100.13, Advanced/Proceed, модель
Qwen2.5-1.5B-Instruct, ключ sk-lab-local) и гигиена (tmp-*.sh в scripts/,
мусор на VM — см. 23.11).

---

## Обновление 2026-11-24 (вечер): ЗАДАНИЕ ПОЛНОСТЬЮ ВЫПОЛНЕНО И ПРИНЯТО

- Пользовательская проверка в GUI VM1 пройдена: браузер ->
  https://192.168.100.13 (NextChat) -> Qwen2.5-1.5B-Instruct отвечает в
  веб-интерфейсе. Полная цепочка VM1 -> nginx(443) -> NextChat -> vLLM(VM4)
  работает насквозь.
- Гигиена выполнена: 18 tmp-*.sh в scripts/ убиты; VM4 — image v0.16.0,
  старые tar (vllm-openai.tar, latest.tar, vllm-cpu-v034.tar.gz),
  tmp-debug*.sh, m4-list.txt, vm4-incoming/ (диск 27G -> 18G); VM1 — scp-*
  логи/флаги, логи hf/pull/save/push/smoke/bootstrap, m1-list.txt;
  VM2/VM3 были чисты. После чистки vllm Up, DOCKER-USER на месте.
- ОСТАВЛЕНО осознанно: ~/vm4-artifacts на VM1 (7.2 GB — единственный
  резерв артефактов vLLM: модель + tar образов) и рабочие скрипты
  05/11/30/32 в домах VM (документируют настройку). Удалить артефакты
  можно после вывода стенда из эксплуатации.

ИТОГ ВСЕГО ЗАДАНИЯ (19-24.11): 4 VM Hyper-V (Desktop + 3 Server),
NTP-сервер (ntpsec) + клиенты (timesyncd), NextChat+nginx+self-signed на
VM3, vLLM CPU (v0.34.0, eager, KV 1G) на VM4, ufw везде, изоляция
VM1->VM4 через DOCKER-USER, скриптовая (40-verify.sh) и пользовательская
проверки пройдены. Стенд готов к сдаче.
