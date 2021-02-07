# Домашнее задание. Инициализация системы. Systemd

```
Systemd
Выполнить следующие задания и подготовить развёртывание результата выполнения с использованием Vagrant и Vagrant shell provisioner (или Ansible, на Ваше усмотрение):
1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig);
2. Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi);
3. Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами;
4*. Скачать демо-версию Atlassian Jira и переписать основной скрипт запуска на unit-файл.
```

#### 1.Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig)

Создать файл /etc/sysconfig/keyword и привести к виду:
```
WORD="ERROR"
LOG=/var/log/keyword.log
```
Создать соответствующий лог-файл /var/log/keyword.log:
```
Feb  7 13:19:02 localhost kernel: Initializing cgroup subsys cpuset
Feb  7 13:19:02 localhost kernel: Initializing cgroup subsys cpu
Feb  7 13:19:02 localhost kernel: Initializing cgroup subsys cpuacct
Feb  7 13:19:02 localhost kernel: Linux version 3.10.0-1127.el7.x86_64 (mockbuild@kbuilder.bsys.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-39) (GCC) ) #1 SMP Tue Mar 31 23:36:51 UTC 2020
Feb  7 13:19:02 localhost kernel: Command line: BOOT_IMAGE=/boot/vmlinuz-3.10.0-1127.el7.x86_64 root=UUID=1c419d6c-5064-4a2b-953c-05b2c67edb15 ro no_timer_check console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0 elevator=noop crashkernel=auto LANG=en_US.UTF-8
Feb  7 13:19:02 localhost kernel: e820: BIOS-provided physical RAM map:
Feb  7 13:19:02 localhost kernel: BIOS-e820: ERROR [mem 0x0000000000000000-0x000000000009fbff] usable     #  Ключевое слово
Feb  7 13:19:02 localhost kernel: BIOS-e820: [mem 0x000000000009fc00-0x000000000009ffff] reserved
Feb  7 13:19:02 localhost kernel: BIOS-e820: [mem 0x00000000000f0000-0x00000000000fffff] reserved
Feb  7 13:19:02 localhost kernel: BIOS-e820: [mem 0x0000000000100000-0x000000001ffeffff] usable
Feb  7 13:19:02 localhost kernel: BIOS-e820: [mem 0x000000001fff0000-0x000000001fffffff] ACPI data
Feb  7 13:19:02 localhost kernel: BIOS-e820: [mem 0x00000000fec00000-0x00000000fec00fff] reserved
Feb  7 13:19:02 localhost kernel: BIOS-e820: [mem 0x00000000fee00000-0x00000000fee00fff] reserved
Feb  7 13:19:02 localhost kernel: BIOS-e820: [mem 0x00000000fffc0000-0x00000000ffffffff] reserved
Feb  7 13:19:02 localhost kernel: NX (Execute Disable) protection: active
Feb  7 13:19:02 localhost kernel: SMBIOS 2.5 present.
```

Создать скрипт search.sh со следующим содержимым:
```
#!/bin/bash
WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
logger "$DATE: Bingo"         # лог будет отправлен в /var/log/messages
else
exit 0
fi
```

Создать следующий юнит в /etc/systemd/system/keyword.service:
```
[Unit]
Description=Find a keyword
[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/keyword
ExecStart=/search.sh $WORD $LOG
```

Создать файл таймера nano /etc/systemd/system/keyword.timer:

```
[Unit]
Description=Start script every 30 seconds
[Timer]
OnActiveSec=1sec # Активировать .service при активации таймера (запуск)
OnCalendar=*:*:0/30  # Точность
Unit=keyword.service
[Install]
WantedBy=multi-user.target
```
Добавить сервис таймера в автозагрузку и запустить:
```
sudo systemctl enable keyword.timer
sudo systemctl start keyword.timer
```

Проверить работу сервисов:
```
tail -f /var/log/messages
Feb  7 14:10:38 localhost systemd: Starting Find a keyword...
Feb  7 14:10:38 localhost root: Sun Feb  7 14:10:38 UTC 2021: BINGO
Feb  7 14:10:38 localhost systemd: Started Find a keyword.
Feb  7 14:10:38 localhost systemd: Stopped Start script every 30 seconds.
Feb  7 14:10:39 localhost systemd: Started Start script every 30 seconds.
Feb  7 14:10:40 localhost systemd: Stopped Start script every 30 seconds.
Feb  7 14:10:40 localhost systemd: Started Start script every 30 seconds.
Feb  7 14:10:41 localhost systemd: Stopped Start script every 30 seconds.
Feb  7 14:10:42 localhost systemd: Started Start script every 30 seconds.
Feb  7 14:10:45 localhost systemd: Starting Find a keyword...
Feb  7 14:10:46 localhost root: Sun Feb  7 14:10:45 UTC 2021: BINGO
Feb  7 14:10:46 localhost systemd: Started Find a keyword.
```

