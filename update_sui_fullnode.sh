#!/bin/bash
# Check if the operating system is Ubuntu
if [ "$(cat /etc/os-release | grep -i "ID=ubuntu" | cut -d'=' -f2)" != "ubuntu" ]; then
    echo "This OS is not Ubuntu. Exiting..."
    exit 1
fi
#Check run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root.\n Use command: 'sudo -i' and re-run the script"
    exit 1
fi

if [ -n "$(systemctl status suid | grep Acwtive)" ]; then
    echo -e "SUI is not installed. Please install SUI first.\nAccess https://github.com/vup2p/sui_monitor and follow the instructions."
    exit 1
fi
#Check run in screen
if [ -n "$STY" ]; then
    echo "This is a screen session named '$STY'"
    echo "Start Update SUI Network"
else
    echo -e "This is NOT a screen session. Use command: 'screen -S SUI' and re-run the script\n"
    apt install screen -y >/dev/null 2>&1
    exit 0
fi

systemctl stop suid
cd $HOME/sui
source $HOME/.cargo/env
cargo clean

config=$(cat /etc/systemd/system/suid.service | grep "config-path" | awk '{print $3}')
dbfile=$(cat $config | grep db-path | awk '{print $2}' | tr -d \")
genesis=$(cat $config | grep genesis-file-location | awk '{print $2}' | tr -d \")

read -r -p "Do you want to delete the Database? (y/n)" deldb
if [ "$deldb" == "y" ]; then
rm -r $dbfile $genesis
else
rm -r $genesis
fi

wget -O $genesis https://github.com/MystenLabs/sui-genesis/raw/main/devnet/genesis.blob
git fetch upstream
git checkout -B devnet --track upstream/devnet
ldconfig
cargo build --release
cp target/release/sui-node $(which sui-node)
cp target/release/sui $(which sui)
systemctl start suid
wget -O ~/check_sui_sync.sh https://raw.githubusercontent.com/vup2p/sui_monitor/main/check_sui_sync.sh >/dev/null 2>&1
chmod +x ~/check_sui_sync.sh
cargo clean

echo "Sui Version: `sui -V`"
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