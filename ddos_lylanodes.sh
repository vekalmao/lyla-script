#!/bin/bash

install_lylanodes_protection() {
    if [ -d "/etc/lylanodes-protection" ]; then
        echo "LylaNodes Protection is already installed."
        return
    fi

    cd /etc/
    apt update
    mkdir lylanodes-protection
    cd lylanodes-protection
    curl -Lo ddos-guardian.tar.gz https://github.com/DDOS-Guardian/DDoS-Guardian/releases/latest/download/ddos-guardian.tar.gz
    tar -xvzf ddos-guardian.tar.gz
    rm ddos-guardian.tar.gz

    if ! command -v node &> /dev/null; then
        echo "Please install NodeJS!"
        exit 1
    fi

    npm install

cat <<EOF > /etc/systemd/system/lylanodes.service
[Unit]
Description=LylaNodes Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/lylanodes-protection
ExecStart=/usr/bin/node /etc/lylanodes-protection/attacks.js
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable lylanodes
    systemctl start lylanodes

    iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p udp -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -j DROP
    
    iptables -A INPUT -i lo -j ACCEPT
    
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    
    iptables -A INPUT -p icmp -m limit --limit 1/s -j ACCEPT
    
    iptables -A INPUT -j LOG --log-prefix "Dropped: "
    
    iptables -A INPUT -j DROP
    
    iptables-save > /etc/iptables/rules.v4
    
    cd /etc/nginx/conf.d/
    
    curl -Lo protect.lua https://raw.githubusercontent.com/vekalmao/lyla-script-layer-7/main/protect.lua
    
    apt-get install libnginx-mod-http-lua
    
    echo "LylaNodes Protection Setup complete"
}

uninstall_lylanodes_protection() {
    if [ ! -d "/etc/lylanodes-protection" ]; then
        echo "LylaNodes Protection is not currently installed."
        return
    fi

    systemctl stop lylanodes
    systemctl disable lylanodes

    rm -rf /etc/lylanodes-protection
    rm /etc/systemd/system/lylanodes.service
    rm /etc/nginx/conf.d/protect.lua
    apt-get remove --purge libnginx-mod-http-lua
    
    iptables -F
    iptables-save > /etc/iptables/rules.v4

    echo "LylaNodes Protection Uninstallation complete"
}

# Main menu
echo "Choose what to do:"
echo "1. Install LylaNodes Protection"
echo "2. Uninstall LylaNodes Protection"
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        confirm_installation
        ;;
    2)
        uninstall_lylanodes_protection
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

exit 0
