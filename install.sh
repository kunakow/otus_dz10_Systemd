#!/bin/bash
echo -e "WORD=\"ERROR\"\nLOG=/var/log/keyword.log" | sudo tee -a /etc/sysconfig/keyword
echo -e "ERROR" | sudo tee -a /var/log/keyword.log
echo -e " #!/bin/bash\nWORD=\$1\nLOG=\$2\nDATE=\`date\`\nif grep \$WORD \$LOG &> /dev/null\nthen\nlogger \"\$DATE: Bingo\"\nelse\nexit 0\nfi" | sudo tee -a /opt/search.sh
sudo chmod +x /opt/search.sh
echo -e "[Unit]\nDescription=Find a keyword\n[Service]\nType=oneshot\nEnvironmentFile=/etc/sysconfig/keyword\nExecStart=/opt/search.sh \$WORD \$LOG" | sudo tee -a /etc/systemd/system/keyword.service
echo -e "[Unit]\nDescription=Start script every 30 seconds\n[Timer]\nOnActiveSec=1sec\nOnCalendar=*:*:0/30\nUnit=keyword.service\n[Install]\nWantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/keyword.timer
sudo systemctl enable keyword.timer
sudo systemctl start keyword.timer
sudo yum install epel-release -y
sudo yum install spawn-fcgi php php-cli mod_fcgid httpd -y
echo -e "SOCKET=/var/run/php-fcgi.sock\nOPTIONS=\"-u apache -g apache -s \$SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi\"" | sudo tee -a  /etc/sysconfig/spawn-fcgi
echo -e "[Unit]\nDescription=Spawn-fcgi\nAfter=network.target\n[Service]\nType=simple\nPIDFile=/var/run/spawn-fcgi.pid\nEnvironmentFile=/etc/sysconfig/spawn-fcgi\nExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS\nKillMode=process\n[Install]\nWantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/spawn-fcgi.service
sudo systemctl enable spawn-fcgi.service
sudo touch /etc/systemd/system/httpd@.service
echo -e "[Unit]\nDescription=The Apache HTTP Server\nAfter=network.target remote-fs.target nss-lookup.target\nDocumentation=man:httpd(8)\nDocumentation=man:apachectl(8)\n[Service]\nType=notify\nEnvironmentFile=/etc/sysconfig/httpd%I\nExecStart=/usr/sbin/httpd \$OPTIONS -DFOREGROUND\nExecReload=/usr/sbin/httpd \$OPTIONS -k graceful\nExecStop=/bin/kill -WINCH \${MAINPID}\nKillSignal=SIGCONT\nPrivateTmp=true\n[Install]\nWantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/httpd@.service
echo -e "OPTIONS=-f conf/httpd1.conf" | sudo tee -a /etc/sysconfig/httpd1
echo -e "OPTIONS=-f conf/httpd2.conf" | sudo tee -a /etc/sysconfig/httpd2
sudo cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd1.conf
sudo cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd2.conf
echo -e "LISTEN 8000\nPidFile /etc/httpd/run/httpd1.pid" | sudo tee -a /etc/httpd/conf/httpd1.conf
echo -e "LISTEN 8001\nPidFile /etc/httpd/run/httpd2.pid" | sudo tee -a /etc/httpd/conf/httpd2.conf
sudo setenforce 0
systemctl enable httpd@1.service
systemctl enable httpd@2.service
systemctl start httpd@2.service
systemctl start httpd@2.service
