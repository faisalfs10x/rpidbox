#!/bin/bash
: '
Coded by: @faisalfs10x
GitHub: https://github.com/faisalfs10x
 '

echo -e "\n[+] SETUP SSH REVERSE TUNNEL IN PI-BOX FOR REMOTE ACCESS [+]\n"

if [[ $EUID -ne 0 ]]; then
   echo "[-] This script must be run as root. Pls use sudo !!"
   echo "[-] You are running as user: $USER"
   exit 1
fi

echo -e "\n[+] Update kali repo\n"
cat << EOF > /etc/apt/sources.list
deb http://http.kali.org/kali kali-rolling main non-free contrib
deb-src http://http.kali.org/kali kali-rolling main non-free contrib
EOF

echo -e "[+] Set Google DNS\n"
cat << EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

#echo -e "Reduce power save level\n"
#cat << EOF > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
#wifi.powersave = 2
#EOF

echo -e "[+] Restarting NetworkManager\n"
systemctl restart NetworkManager

echo -e "[+] Apt Update\n"
apt update -y

echo -e "\n[+] Are you want to perform Full-Upgrade, it may take looooong time!!"
read -p "[+] Are you sure? really sure? pls type N for NO: " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
   echo -e "[+] Full-Upgrade, pls have a coffee..."
   apt -y full-upgrade
   sleep 2
fi

echo -e "\n[+] Installing Tools\n"
apt-get install -y openssh-server responder macchanger voiphopper snmpcheck onesixtyone patator isr-evilgrade screen netexec xrdp autossh sshpass

sleep 2

echo -e "\n[+] Enable SSH\n"
systemctl start ssh
systemctl enable ssh

echo -e "\n[+] Enable RDP\n"
service xrdp-sesman start
systemctl enable xrdp

echo -e "\n[+] Setting up timezone to Asia/Singapore"
timedatectl set-timezone 'Asia/Singapore'

echo -e "\n[+] Setting up hostname"
CURRENT_HOSTNAME=$(hostnamectl | grep "Static hostname" | awk '{print $3}')
echo -e "[+] Enter a new hostname (or press enter to keep the current hostname as $CURRENT_HOSTNAME):"
read NEW_HOSTNAME

if [ -n "$NEW_HOSTNAME" ]; then
    echo -e "\n[+] Set hostname to $NEW_HOSTNAME? (y/n)"
    read answer
    if [ "$answer" == "y" ]; then
        sed -i "s/^127.0.1.1\s*$CURRENT_HOSTNAME$/127.0.1.1 $NEW_HOSTNAME/g" /etc/hosts
        hostnamectl set-hostname $NEW_HOSTNAME
        systemctl restart systemd-hostnamed.service
        echo "[+] Hostname set to $NEW_HOSTNAME"
    else
        echo "[+] Hostname unchanged ($CURRENT_HOSTNAME)"
    fi
else
    echo "[+] Hostname unchanged ($CURRENT_HOSTNAME)"
fi

echo -e "[+] Setting up ssh-keygen for local user:\n"

echo -e "[+] Enter local username to allow for tunneling, eg pi-tunnel:\n[+] Make sure the selected local user can SSH into this host !!"
read LUSER
echo -e "\n[+] The username for tunneling will be $LUSER \n"

echo "[+] Check if SSH key is already installed...."

if [ -f /home/$LUSER/.ssh/id_rsa ]; then
  echo "[+] SSH key is already installed"
  sudo -u $LUSER chmod 600 /home/$LUSER/.ssh/id_rsa
else
  echo -e "[-] SSH key doesn't exist. Generating new one"
  echo -e "[+] Generating a new SSH key pair with no passphrase\n"
  sudo -u $LUSER ssh-keygen -t rsa -b 4096 -f /home/$LUSER/.ssh/id_rsa -N ""
  sudo -u $LUSER chmod 600 /home/$LUSER/.ssh/id_rsa
  echo -e "\n[+] SSH key generated successfully"
fi

echo -e "\n[+] Enter IP of remote SSH host, eg 128.78.6.45"
read TARGETIP

echo -e "\n[+] Enter username on remote SSH host, eg tunnel-user"
read RUSER

echo -e "\n[+] Enter password used for ssh login to $RUSER on $TARGETIP, eg P@ssw0rd"
read USERPASS

echo -e "\n[+] Enter the remote SSH port (default: 22)"
read SSHPORT
if [ -z "$SSHPORT" ]; then
  SSHPORT="22"
fi

echo -e "\n[+] Enter the SSH public key file location (default: /home/$LUSER/.ssh/id_rsa.pub):\n"
read SSH_PUBKEY
if [ -z "$SSH_PUBKEY" ]; then
  SSH_PUBKEY="/home/$LUSER/.ssh/id_rsa.pub"
  echo -e "[+] Location for SSH_PUBKEY is $SSH_PUBKEY"
  SSH_PRIVKEY="${SSH_PUBKEY%.pub}"
  echo -e "[+] Location for SSH_PRIVKEY is $SSH_PRIVKEY\n"

else
  echo -e "\n[+] You have manually enter SSH public key location"
  SSH_PUBKEY="$SSH_PUBKEY"
  echo -e "[+] Entered location for SSH_PUBKEY is $SSH_PUBKEY"
  SSH_PRIVKEY="${SSH_PUBKEY%.pub}"
  echo -e "[+] Entered location for SSH_PRIVKEY is $SSH_PRIVKEY\n"    
fi

echo -e "[+] Copying SSH_PUBKEY to remote host $TARGETIP\n"
sshpass -p $USERPASS echo ssh-copy-id -i $SSH_PUBKEY -p $SSHPORT $RUSER@$TARGETIP #prints the ssh-copy-id command to the console. The echo here is to show what the resulting command would be, without actually executing it.
eval sshpass -p $USERPASS ssh-copy-id -i $SSH_PUBKEY -p $SSHPORT $RUSER@$TARGETIP

echo -e "[+] Testing the SSH connection"
if ssh -q -oBatchMode=yes -oConnectTimeout=5 -i $SSH_PRIVKEY -p $SSHPORT $RUSER@$TARGETIP exit; then
  echo -e "[+] SSH connection successful"
else
  echo -e "[-] SSH connection failed. Pls recheck any error"
  exit 1
fi

sleep 2

echo -e "\n[+] Setting up systemd service for persistence across reboot ;)"
echo -e "\n[+] Please enter systemd file name, eg tunnel or revtunnel"
read -r SYSTEMD_NAME
echo -e "\n[+] The systemd file will be in /etc/systemd/system/$SYSTEMD_NAME.service"

echo -e "\n[+] Please enter SSH tunnel -R PORT on remote host, eg 6666"
read -r REMOTESSHPORT

cat << EOF > /etc/systemd/system/$SYSTEMD_NAME.service
[Unit]
Description=AutoSSH tunnel service to $TARGETIP on remote port $REMOTESSHPORT
#After=network.target network-online.target sshd.service
After=network-online.target

[Service]
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -NR $REMOTESSHPORT:127.0.0.1:$SSHPORT $RUSER@$TARGETIP -p $SSHPORT -i $SSH_PRIVKEY
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

sleep 2

echo -e "\n[+] Reload daemon & start $SYSTEMD_NAME.service:\n"
systemctl daemon-reload
systemctl start $SYSTEMD_NAME.service
systemctl enable $SYSTEMD_NAME.service

echo -e "\n[+] Donee\n[+] We can now login with [ ssh $LUSER@127.0.0.1 -p $REMOTESSHPORT ] on remote SSH host $TARGETIP"
