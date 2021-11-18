echo "Update kali repo"
cat << EOF > /etc/apt/sources.list
deb http://http.kali.org/kali kali-rolling main non-free contrib
deb-src http://http.kali.org/kali kali-rolling main non-free contrib
EOF

echo "Set Google DNS"
cat << EOF > /etc/resolv.conf
8.8.8.8
8.8.4.4
EOF

echo "Update & Full-Upgrade"
apt update -y && apt -y full-upgrade -y

echo "Install Tools"
apt-get install -y openssh-server responder macchanger voiphopper snmpcheck onesixtyone patator isr-evilgrade screen crackmapexec xrdp autossh sshpass

echo "Enable RDP"
service xrdp-sesman start
systemctl enable xrdp

echo "Setting up timezone to Asia/Singapore"
timedatectl set-timezone 'Asia/Singapore'

echo "Setting up hostname, pls insert new hostname"
read -r CHG_HOSTNAME
hostnamectl set-hostname $CHG_HOSTNAME

echo "Setting up ssh-keygen to remote host"
sudo -u root bash -c "ssh-keygen -f ~root/.ssh/id_rsa -N ''"

echo "Please insert the password used for ssh login on remote machine:"
read -r USERPASS

echo "Please insert the location of id_rsa.pub file, eg /root/.ssh/id_rsa.pub :"
read -r KEYLOCATION

echo "Please insert username remote host:"
read -r USER

echo "Please insert IP of remote host:"
read -r TARGETIP

echo "Please insert ssh PORT of remote host:"
read -r SSHPORT

echo "$USERPASS" | sshpass ssh-copy-id -f -i $KEYLOCATION "$USER"@"$TARGETIP"

echo "Setting up systemd service as autossh-ptunnel.service:"

echo "Please insert ssh tunnel -R PORT on remote host, eg 6666:"
read -r SSHPORT

cat << EOF > /etc/systemd/system/autossh-ptunnel.service
[Unit]
Description=AutoSSH tunnel service nyekeng-baru on remote port $SSHPORT
After=network.target

[Service]
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 11166 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "PubkeyAuthentication=yes" -o "PasswordAuthentication=no" -N -i $KEYLOCATION -R $SSHPORT:localhost:$SSHPORT $USER@$TARGETIP

[Install]
WantedBy=multi-user.target

#After=network.target - after network is up
#ServerAliveInterval - this tells SSH to test the connection every 30 seconds
#ServerAliveCountMax - assume failure after 3 consecutive failed messages. Such configuration ensures a quick recovery after the connection failure.
EOF

echo "Reload daemon & start autossh-ptunnel.service:"

systemctl daemon-reload
systemctl start autossh-ptunnel.service
systemctl enable autossh-ptunnel.service
