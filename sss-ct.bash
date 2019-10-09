#!/bin/bash

CONFIG_FILE=/etc/shadowsocks.json
SERVICE_FILE=/etc/systemd/system/shadowsocks.service
SS_PASSWORD=${1}
SS_PORT=${2}
SS_METHOD=aes-256-cfb
GET_PIP_FILE=/tmp/get-pip.py

sleep5
echo systemctl stop firewalld.service > /root/ss_init.log
systemctl stop firewalld.service > /root/ss_init.log
echo systemctl disable firewalld.service >> /root/ss_init.log
systemctl disable firewalld.service >> /root/ss_init.log
echo systemctl mask firewalld >> /root/ss_init.log
systemctl mask firewalld >> /root/ss_init.log

yum install -qy iptables
echo yum install -qy iptables-services >> /root/ss_init.log
yum install -qy iptables-services >> /root/ss_init.log
systemctl enable iptables.service

iptables -F
iptables -X
iptables -Z
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -A INPUT -p tcp --dport ${SS_PORT} -j ACCEPT

service iptables save
systemctl restart iptables.service

iptables -L -n >> /root/ss_init.log

echo yum install -qy  python >> /root/ss_init.log
yum install -qy python >> /root/ss_init.log 2>&1

sleep 5

# install pip
curl "https://bootstrap.pypa.io/get-pip.py" -o "${GET_PIP_FILE}"
python ${GET_PIP_FILE} >> /root/ss_init.log 2>&1

# install shadowsocks
pip install --upgrade pip >> /root/ss_init.log 2>&1
pip install shadowsocks >> /root/ss_init.log 2>&1

# create shadowsocls config
cat <<EOF | sudo tee ${CONFIG_FILE}
{
  "server": "0.0.0.0",
  "server_port": ${SS_PORT},
  "password": "${SS_PASSWORD}",
  "method": "${SS_METHOD}"
}
EOF

# create service
cat <<EOF | sudo tee ${SERVICE_FILE}
[Unit]
Description=Shadowsocks

[Service]
TimeoutStartSec=0
ExecStart=$(which ssserver) -c ${CONFIG_FILE}

[Install]
WantedBy=multi-user.target
EOF

# start service
systemctl enable shadowsocks >> /root/ss_init.log 2>&1
systemctl start shadowsocks >> /root/ss_init.log 2>&1

# view service status
#sleep 5
#systemctl status shadowsocks -l >> /root/ss_init.log 2>&1

sleep 5
yum install -qy nginx
service nginx start

cat > /root/change_ssport.bash << \EOF

#!/bin/bash

if [ ! -z "$1" ]; then
SS_PORT=$1
yum install -qy vim
iptables -A INPUT -p tcp --dport ${SS_PORT} -j ACCEPT
sed -i "s/\(\"server_port\"\: \)\([0-9]*\)\(\,\)/\1${SS_PORT},/g" /etc/shadowsocks.json
systemctl restart shadowsocks
systemctl status shadowsocks -l
fi
EOF
chmod +x /root/change_ssport.bash