apt-get install -y responder macchanger voiphopper snmpcheck onesixtyone patator isr-evilgrade screen crackmapexec xrdp

service xrdp-sesman start

systemctl enable xrdp

timedatectl set-timezone 'Asia/Singapore'


cat << EOF > /etc/systemd/system/autossh-ptunnel.service
[Unit]
Description=AutoSSH tunnel service nyekeng-baru on remote port 6666
After=network.target

[Service]
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 11166 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "PubkeyAuthentication=yes" -o "PasswordAuthentication=no" -N -i /root/.ssh/id_rsa -R 6666:localhost:22 ptunnel@206.189.91.246

[Install]
WantedBy=multi-user.target

#After=network.target - after network is up
#ServerAliveInterval - this tells SSH to test the connection every 30 seconds
#ServerAliveCountMax - assume failure after 3 consecutive failed messages. Such configuration ensures a quick recovery after the connection failure.
EOF


systemctl daemon-reload
systemctl start autossh-ptunnel.service
systemctl enable autossh-ptunnel.service
