
if [ -d "/etc/lyla-protection" ]; then
    echo "Removing existing /etc/lyla-protection directory..."
    rm -rf /etc/lyla-protection
fi


mkdir /etc/lyla-protection


cd /etc/lyla-protection


git clone https://github.com/vekalmao/lyla-script .


if ! command -v node &> /dev/null; then
    curl -sL https://deb.nodesource.com/setup_14.x | bash -
    apt install -y nodejs
fi


npm install


apt update
apt upgrade -y


cat <<EOF > /etc/systemd/system/lylanodes.service
[Unit]
Description=LylaNodes Protection Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/lyla-protection
ExecStart=/usr/bin/node /etc/lyla-protection/attacks.js
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload


systemctl enable lylanodes
systemctl start lylanodes



cd /etc/nginx/conf.d/
sudo apt-get install libnginx-mod-http-lua

if [ -d "lyla-script-layer-7" ]; then
    echo "Removing existing /etc/nginx/conf.d/lyla-script-layer-7 directory..."
    rm -rf lyla-script-layer-7
fi

git clone https://github.com/vekalmao/lyla-script-layer-7

echo "LylaNodes Protection has been updated."
