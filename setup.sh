echo "Update kali repo\n"
cat << EOF > /etc/apt/sources.list
deb http://http.kali.org/kali kali-rolling main non-free contrib
deb-src http://http.kali.org/kali kali-rolling main non-free contrib
EOF

echo "Set Google DNS\n"
cat << EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

echo "Update & Full-Upgrade\n"
apt update -y && apt -y full-upgrade -y

echo "Install Tools\n"
apt-get install -y openssh-server responder macchanger voiphopper snmpcheck onesixtyone patator isr-evilgrade screen crackmapexec xrdp autossh sshpass

echo "Enable RDP\n"
service xrdp-sesman start
systemctl enable xrdp

echo "Setting up timezone to Asia/Singapore\n"
timedatectl set-timezone 'Asia/Singapore'

echo "Setting up hostname, pls insert new hostname\n"
read -r CHG_HOSTNAME
hostnamectl set-hostname $CHG_HOSTNAME

echo "Setting up ssh-keygen to remote host for user root\n"
sudo -u root bash -c "ssh-keygen -f ~root/.ssh/id_rsa -N ''"

echo "Please insert the password used for ssh login on remote machine, eg P@ssw0rd:\n"
read -r USERPASS

echo "Please insert the location of id_rsa.pub file, eg /root/.ssh/id_rsa.pub :\n"
read -r KEYLOCATION

echo "Please insert username remote host, eg root:\n"
read -r USER

echo "Please insert IP of remote host, eg 128.78.6.45:\n"
read -r TARGETIP

echo "Please insert ssh PORT of remote host, eg 22:\n"
read -r SSHPORT

echo "$USERPASS" | sshpass ssh-copy-id -f -i $KEYLOCATION "$USER"@"$TARGETIP"

echo "Setting up systemd service as autossh-ptunnel.service:"
echo "Please insert systemd file name, eg tunnel or revtunnel:\n"
read -r SYSTEMD_NAME
echo "The systemd file will be in /etc/systemd/system/$SYSTEMD_NAME.service:\n"

echo "Please insert ssh tunnel -R PORT on remote host, eg 6666:\n"
read -r REMOTESSHPORT

cat << EOF > /etc/systemd/system/$SYSTEMD_NAME.service
[Unit]
Description=AutoSSH tunnel service nyekeng-baru on remote port $REMOTESSHPORT
After=network.target

[Service]
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 11166 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "PubkeyAuthentication=yes" -o "PasswordAuthentication=no" -N -i $KEYLOCATION -R $REMOTESSHPORT:localhost:$SSHPORT $USER@$TARGETIP

[Install]
WantedBy=multi-user.target

#After=network.target - after network is up
#ServerAliveInterval - this tells SSH to test the connection every 30 seconds
#ServerAliveCountMax - assume failure after 3 consecutive failed messages. Such configuration ensures a quick recovery after the connection failure.
EOF

echo "Reload daemon & start $SYSTEMD_NAME.service:\n"
systemctl daemon-reload
systemctl start autossh-ptunnel.service
systemctl enable autossh-ptunnel.service


