#!/bin/bash

echo -e "Update kali repo\n"
cat << EOF > /etc/apt/sources.list
deb http://http.kali.org/kali kali-rolling main non-free contrib
deb-src http://http.kali.org/kali kali-rolling main non-free contrib
EOF

echo -e "Set Google DNS\n"
cat << EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

echo -e "Reduce power save level\n"
cat << EOF > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
wifi.powersave = 2
EOF

echo -e "Restarting NetworkManager\n"
systemctl restart NetworkManager

echo -e "Apt Update\n"
apt update -y

echo -e "Are you want to perform Full-Upgrade, it may take looooong time!!"
read -p "Are you sure? really sure? pls type N for NO: " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
   apt -y full-upgrade -y
fi

echo -e "Install Tools\n"
apt-get install -y openssh-server responder macchanger voiphopper snmpcheck onesixtyone patator isr-evilgrade screen crackmapexec xrdp autossh sshpass

echo -e "Enable SSH\n"
systemctl start ssh
systemctl enable ssh

echo -e "Enable RDP\n"
service xrdp-sesman start
systemctl enable xrdp

echo -e "Setting up timezone to Asia/Singapore\n"
timedatectl set-timezone 'Asia/Singapore'

echo -e "Setting up hostname, pls insert new hostname\n"
read -r CHG_HOSTNAME
hostnamectl set-hostname $CHG_HOSTNAME

echo -e "Setting up ssh-keygen to remote host for user root\n"
sudo -u root bash -c "ssh-keygen -f ~root/.ssh/id_rsa -N ''"
chmod 600 /root/.ssh/id_rsa.pub

echo -e "Setting up ssh-copy-id to remote host\n"

echo -e "Please insert username remote host, eg root:\n"
read -r USER

echo -e "Please insert the password used for ssh login on remote machine, eg P@ssw0rd:\n"
read -r USERPASS

echo -e "Please insert the location of id_rsa.pub file, eg /root/.ssh/id_rsa.pub :\n"
read -r KEYLOCATION

echo -e "Please insert IP of remote host, eg 128.78.6.45:\n"
read -r TARGETIP

echo -e "Please insert ssh PORT of remote host, eg 22:\n"
read -r SSHPORT

echo -e "Copying $KEYLOCATION to $USER@$TARGETIP on $SSHPORT:\n"
echo "$USERPASS" | sshpass ssh-copy-id -f -i $KEYLOCATION -p $SSHPORT $USER@$TARGETIP

echo -e "Setting up systemd service as $SYSTEMD_NAME.service:"
echo -e "Please insert systemd file name, eg tunnel or revtunnel:\n"
read -r SYSTEMD_NAME
echo -e "The systemd file will be in /etc/systemd/system/$SYSTEMD_NAME.service:\n"

echo -e "Please insert ssh tunnel -R PORT on remote host, eg 6666:\n"
read -r REMOTESSHPORT

cat << EOF > /etc/systemd/system/$SYSTEMD_NAME.service
[Unit]
Description=AutoSSH tunnel service nyekeng-baru on remote port $REMOTESSHPORT
#After=network.target network-online.target sshd.service
After=network-online.target

[Service]
Environment="AUTOSSH_GATETIME=0"
#ExecStart=/usr/bin/autossh -M 0 -o "ExitOnForwardFailure=yes" -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -NR $REMOTESSHPORT:127.0.0.1:$SSHPORT $USER@$TARGETIP -p $SSHPORT -i /root/.ssh/id_rsa
ExecStart=/usr/bin/autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -NR $REMOTESSHPORT:127.0.0.1:$SSHPORT $USER@$TARGETIP -p $SSHPORT -i /root/.ssh/id_rsa
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target

#After=network.target - after network is up
#After=network-online.target - only attempts to run if its connected to a network (important for wifi-connected devices).
#ServerAliveInterval - this tells SSH to test the connection every 30 seconds
#ServerAliveCountMax - assume failure after 3 consecutive failed messages. Such configuration ensures a quick recovery after the connection failure.
# -M 0 --> no monitoring
# -N Just open the connection and do nothing (not interactive)
EOF

echo -e "Reload daemon & start $SYSTEMD_NAME.service:\n"
systemctl daemon-reload
systemctl start $SYSTEMD_NAME.service
systemctl enable $SYSTEMD_NAME.service


