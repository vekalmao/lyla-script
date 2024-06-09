#!/bin/bash

DIR="/etc/lylanodes-protection"

if [ -d "$DIR" ]; then
    echo "Directory $DIR already exists."
    exit 1
fi

mkdir -p $DIR

cd $DIR

git clone https://github.com/vekalmao/lyla-script/ .

if ! command -v node &> /dev/null; then
    curl -sL https://deb.nodesource.com/setup_14.x | bash -
    apt install -y nodejs
fi

apt update
apt upgrade -y

# Install required Node.js modules
npm install express
npm install http-proxy
npm install fs
npm install net
npm install dgram
npm install express-rate-limit

cat <<EOF > /etc/systemd/system/lylanodes.service
[Unit]
Description=LylaNodes DDos Protection
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=/usr/bin/node $DIR/attacks.js
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable lylanodes
systemctl start lylanodes

iptables-save > /etc/iptables/rules.backup

cat <<EOF > /etc/lylanodes-protection/firewall.sh
#!/bin/bash

# Clear existing rules and chains
iptables -F
iptables -X

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Whitelist all IP addresses
iptables -A INPUT -s 0.0.0.0/0 -j ACCEPT

# Allow SSH (port 22) connections
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

# Allow HTTP (port 80) and HTTPS (port 443) connections
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

# Allow ports 8080 and 2022
iptables -A INPUT -p tcp --dport 8080 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 2022 -m conntrack --ctstate NEW -j ACCEPT

# Limit maximum number of TCP connections per IP
iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 10 -j REJECT

# Limit ICMP echo requests
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 3 -j ACCEPT

# Drop invalid packets
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# Drop packets with all TCP flags unset
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Drop packets with all TCP flags set
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Log all other incoming packets
iptables -A INPUT -j LOG --log-prefix "iptables: " --log-level 4

# Allow all outgoing traffic
iptables -A OUTPUT -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4
EOF

chmod +x /etc/lylanodes-protection/firewall.sh

/etc/lylanodes-protection/firewall.sh

sysctl -w net.ipv4.ip_forward=0
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.conf.all.accept_source_route=0
sysctl -w net.ipv6.conf.all.accept_source_route=0
sysctl -w net.ipv4.conf.all.accept_redirects=0
sysctl -w net.ipv6.conf.all.accept_redirects=0
sysctl -w net.ipv4.conf.all.rp_filter=1
sysctl -w net.ipv4.conf.all.log_martians=1

sysctl -p

echo -e "\033[0;32m[ LylaNodes DDos Protection Script Works! ]\033[0m"
echo -e "\033[0;32m[ Made by LylaNodes Hosting ] !\033[0m"
