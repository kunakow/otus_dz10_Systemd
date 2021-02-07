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

#### 2. Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).

Произвести установку пакетов:
```
sudo yum install epel-release
sudo yum install spawn-fcgi
```

Привести файл /etc/sysconfig/spawn-fcg к виду:
```
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```

Создать unit nano /etc/systemd/system/spawn-fcgi.service:

```
[Unit]
Description=Spawn-fcgi
After=network.target
[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process
[Install]
WantedBy=multi-user.target
```
Запустить сервис командой:
```
sudo systemctl start spawn-fcgi.service
sudo systemctl status spawn-fcgi.service

[root@localhost vagrant]# sudo systemctl status spawn-fcgi.service  
● spawn-fcgi.service - Spawn-fcgi
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2021-02-07 14:18:18 UTC; 4s ago
 Main PID: 4609 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─4609 /usr/bin/php-cgi
           ├─4610 /usr/bin/php-cgi
           ├─4611 /usr/bin/php-cgi
           ├─4612 /usr/bin/php-cgi
           ├─4613 /usr/bin/php-cgi
           ├─4614 /usr/bin/php-cgi
           ├─4615 /usr/bin/php-cgi
           ├─4616 /usr/bin/php-cgi
           ├─4617 /usr/bin/php-cgi
           ├─4618 /usr/bin/php-cgi
           ├─4619 /usr/bin/php-cgi
           ├─4620 /usr/bin/php-cgi
           ├─4621 /usr/bin/php-cgi
           ├─4622 /usr/bin/php-cgi
           ├─4623 /usr/bin/php-cgi
           ├─4624 /usr/bin/php-cgi
           ├─4625 /usr/bin/php-cgi
           ├─4626 /usr/bin/php-cgi
           ├─4627 /usr/bin/php-cgi
           ├─4628 /usr/bin/php-cgi
           ├─4629 /usr/bin/php-cgi
           ├─4630 /usr/bin/php-cgi
           ├─4631 /usr/bin/php-cgi
           ├─4632 /usr/bin/php-cgi
           ├─4633 /usr/bin/php-cgi
           ├─4634 /usr/bin/php-cgi
           ├─4635 /usr/bin/php-cgi
           ├─4636 /usr/bin/php-cgi
           ├─4637 /usr/bin/php-cgi
           ├─4638 /usr/bin/php-cgi
           ├─4639 /usr/bin/php-cgi
           ├─4640 /usr/bin/php-cgi
           └─4641 /usr/bin/php-cgi

Feb 07 14:18:18 localhost.localdomain systemd[1]: Started Spawn-fcgi.
```

#### 3. Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами

Скопировать шаблон сервиса:
```
sudo cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@.service
```
Далее, привести скопированный юнит к виду:
```
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)
[Service]

Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I     # Добавляем переменную
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Создать файлы окружения /etc/sysconfig/httpd1 и /etc/sysconfig/httpd2:

```
cat /etc/sysconfig/httpd1
OPTIONS=-f conf/httpd1.conf
```
```
cat /etc/sysconfig/httpd2
OPTIONS=-f conf/httpd2.conf
```
Создать соответствующие конфигурационные файлы /etc/httpd/conf/httpd1.conf и /etc/httpd/conf/httpd2.conf путём копирования файла /etc/httpd/conf/httpd.conf и добавить в них строки:

```
sudo cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd1.conf
sudo cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd2.conf

```
```
cat /etc/sysconfig/httpd1.conf
PORT=8000
PID_FILE=/etc/httpd/run/httpd1.pid
```
```
cat /etc/sysconfig/httpd2.conf
PORT=8001
PID_FILE=/etc/httpd/run/httpd2.pid
```

Отключить selinux командой (в противном случае получим ошибку привязки к порту):
```
sudo setenforce 0
```

Активируем и проверяем сервисы:

```
systemctl start httpd@1.service
systemctl start httpd@2.service
systemctl status httpd@2.service
systemctl status httpd@2.service
```
```
root@localhost sysconfig]# systemctl status httpd@1.service
● httpd@1.service - The Apache HTTP Server
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2021-02-07 16:11:18 UTC; 17s ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 3931 (httpd)
   Status: "Total requests: 0; Current requests/sec: 0; Current traffic:   0 B/sec"
   CGroup: /system.slice/system-httpd.slice/httpd@1.service
           ├─3931 /usr/sbin/httpd -f conf/httpd1.conf -DFOREGROUND
           ├─3932 /usr/sbin/httpd -f conf/httpd1.conf -DFOREGROUND
           ├─3933 /usr/sbin/httpd -f conf/httpd1.conf -DFOREGROUND
           ├─3934 /usr/sbin/httpd -f conf/httpd1.conf -DFOREGROUND
           ├─3935 /usr/sbin/httpd -f conf/httpd1.conf -DFOREGROUND
           ├─3936 /usr/sbin/httpd -f conf/httpd1.conf -DFOREGROUND
           └─3937 /usr/sbin/httpd -f conf/httpd1.conf -DFOREGROUND

Feb 07 16:11:18 localhost.localdomain systemd[1]: Starting The Apache HTTP Server...
Feb 07 16:11:18 localhost.localdomain httpd[3931]: AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using localhost.localdomain....is message
Feb 07 16:11:18 localhost.localdomain systemd[1]: Started The Apache HTTP Server.
Hint: Some lines were ellipsized, use -l to show in full.
[root@localhost sysconfig]# systemctl status httpd@2.service
● httpd@2.service - The Apache HTTP Server
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2021-02-07 16:00:38 UTC; 10min ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 3674 (httpd)
   Status: "Total requests: 0; Current requests/sec: 0; Current traffic:   0 B/sec"
   CGroup: /system.slice/system-httpd.slice/httpd@2.service
           ├─3674 /usr/sbin/httpd -f conf/httpd2.conf -DFOREGROUND
           ├─3675 /usr/sbin/httpd -f conf/httpd2.conf -DFOREGROUND
           ├─3676 /usr/sbin/httpd -f conf/httpd2.conf -DFOREGROUND
           ├─3677 /usr/sbin/httpd -f conf/httpd2.conf -DFOREGROUND
           ├─3678 /usr/sbin/httpd -f conf/httpd2.conf -DFOREGROUND
           ├─3679 /usr/sbin/httpd -f conf/httpd2.conf -DFOREGROUND
           └─3680 /usr/sbin/httpd -f conf/httpd2.conf -DFOREGROUND

Feb 07 16:00:38 localhost.localdomain systemd[1]: Starting The Apache HTTP Server...
Feb 07 16:00:38 localhost.localdomain systemd[1]: Started The Apache HTTP Server.
[root@localhost sysconfig]# 
```
