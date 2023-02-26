#!/bin/bash
# Check if the operating system is Ubuntu
if [ "$(cat /etc/os-release | grep -i "ID=ubuntu" | cut -d'=' -f2)" != "ubuntu" ]; then
    echo "This OS is not Ubuntu. Exiting..."
    exit 1
fi

# Check minimum hardware to run a Sui Full node
cpu=$(lscpu | grep "CPU(s):" | awk '{print $2}' | head -n 1)
ram=$(free | grep Mem | awk '{print $2}')
if [ $cpu -lt 10 ]; then
    echo -e "My node does not meet the minimum CPU requirements:\n $(lscpu | grep "CPU(s):" | head -n 1) "
    echo -e "Suggested minimum hardware to run a Sui Full node:\nCPUs: 10 core\nRAM: 32GB\nStorage (SSD): 1 TB"
    exit 1
elif [ $ram -lt 31000000 ]; then
    echo -e "My node does not meet the minimum RAM requirements:\n $(free -h) \n"
    echo -e "Suggested minimum hardware to run a Sui Full node:\nCPUs: 10 core\nRAM: 32GB\nStorage (SSD): 1 TB\n"
    exit 1
fi

#Check run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root.\n Use command: 'sudo -i' and re-run the script"
    exit 1
fi

#Check port available
check_port() {
    if [ ! -n $1 ]; then
        echo "Please input port number. Ex: check_port 443"
        exit 1
    fi
    if ss -tulpen | awk '{print $5}' | grep -q ":$1$"; then
        echo -e "\e[31mInstallation is not possible, port $1 already in use.\e[39m"
        exit 1
    else
        echo -e "Port $1 isn't use => OK"
    fi
}
check_port 9000
check_port 9184

#Check run in screen
if [ -n "$STY" ]; then
    echo "This is a screen session named '$STY'"
    echo "Start install SUI Network"
else
    echo -e "This is NOT a screen session. Use command: 'screen -S SUI' and re-run the script\n"
    apt install screen -y >/dev/null 2>&1
    exit 0
fi

apt update -y
ldconfig
DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -y --no-install-recommends tzdata git ca-certificates \
    curl build-essential libssl-dev pkg-config libclang-dev cmake jq
echo -e '\n  ===== Install Rust ===== \n' && sleep 1
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
rustup update stable

rm -rf /var/sui/db /var/sui/genesis.blob $HOME/sui
mkdir -p /var/sui/db

cd $HOME

echo -e '\n  =====Install SUI===== \n' && sleep 1
git clone https://github.com/MystenLabs/sui.git
cd sui
git remote add upstream https://github.com/MystenLabs/sui
git fetch upstream
git checkout --track upstream/devnet
cp crates/sui-config/data/fullnode-template.yaml /var/sui/fullnode.yaml

wget -O /var/sui/genesis.blob https://github.com/MystenLabs/sui-genesis/raw/main/devnet/genesis.blob
sed -i.bak "s/db-path:.*/db-path: \"\/var\/sui\/db\"/ ; s/genesis-file-location:.*/genesis-file-location: \"\/var\/sui\/genesis.blob\"/" /var/sui/fullnode.yaml
sed -i.bak 's/127.0.0.1/0.0.0.0/' /var/sui/fullnode.yaml
cargo build --release
mv ~/sui/target/release/sui-node /usr/local/bin/
mv ~/sui/target/release/sui /usr/local/bin/
cargo clean

echo "[Unit]
Description=Sui Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=/usr/local/bin/sui-node --config-path /var/sui/fullnode.yaml
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" >$HOME/suid.service

mv $HOME/suid.service /etc/systemd/system/
tee /etc/systemd/journald.conf <<EOF >/dev/null
Storage=persistent
EOF

systemctl restart systemd-journald
systemctl daemon-reload
systemctl enable suid
systemctl restart suid
wget -O ~/check_sui_sync.sh https://raw.githubusercontent.com/vup2p/sui_monitor/main/check_sui_sync.sh >/dev/null 2>&1
chmod +x ~/check_sui_sync.sh

echo "==================================================="
echo -e '\n\e[43mCheck Sui status\e[0m\n' && sleep 2
if [[ $(service suid status | grep active) =~ "running" ]]; then
    echo -e "Your Sui Node \e[32minstalled and syncing\e[39m!"
    echo -e "You can check node status by the command: \e[7msystemctl status suid\e[0m"
    echo -e "Press \e[7mQ\e[0m for exit from status menu"
    echo -e "You can check node log by the command: \e[7mjournalctl -u suid -f -n 50\e[0m"
    echo -e "You can check sync status by the command: \e[7m~/check_sui_sync.sh\e[0m"
else
    echo -e "Your Sui Node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
echo "Contacts If you have any errors: https://github.com/vup2p"
echo "The script is referenced from Nodes.guru"
