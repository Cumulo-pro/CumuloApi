#!/bin/bash
is_installed()
{
  command -v "$1" >/dev/null 2>&1
}
if is_installed curl; then
echo ''
else
  sudo apt update && sudo apt install curl -y < "/dev/null"
fi
profile_file=$HOME/.bash_profile
if [ -f "$profile_file" ]; then
    source $HOME/.bash_profile
fi
sleep 1 && curl -s https://raw.githubusercontent.com/Cumulo-pro/CumuloApi/main/main/cumulo-logo.sh | bash && sleep 1
RED='\033[0;31m'
RESET='\033[0m'

# Detect the Ubuntu version
ubuntu_version=$(lsb_release -r | awk '{print $2}')

# Convert the version to a comparable number
ubuntu_version_num=$(echo $ubuntu_version | sed 's/\.//')

# Minimum required version for installation
min_required_version=2204

# Compare Ubuntu versions
if [ "$ubuntu_version_num" -lt "$min_required_version" ]; then
    echo -e "${RED}Current Ubuntu Version: "$ubuntu_version".${RESET}"
    echo "" && sleep 1
    echo -e "${RED}Required Ubuntu Version: 22.04.${RESET}"
    echo "" && sleep 1
    echo -e "${RED}Please upgrade to Ubuntu 22.04 or higher.${RESET}"
    exit 1
fi    

NODE_NAME="story"
NODE_HOME="$HOME/.story/story"
EXEC_BINARY="story"
if [ -d "$NODE_HOME" ]; then
    backup_folder="${NODE_HOME}_$(date +"%Y%m%d_%H%M%S")"
    mv "$NODE_HOME" "$backup_folder"
fi

if [ ! $MONIKER ]; then
    read -p "Enter validator name: " MONIKER
    echo 'export MONIKER='\"${MONIKER}\" >> $HOME/.bash_profile
fi
echo 'source $HOME/.bashrc' >> $HOME/.bash_profile
source $HOME/.bash_profile
sleep 1
cd $HOME
sudo apt update
sudo apt install make unzip clang pkg-config lz4 libssl-dev build-essential git jq ncdu bsdmainutils htop -y < "/dev/null"

echo -e '\n\e[42mInstalling Go\e[0m\n' && sleep 1
cd $HOME
VERSION=1.23.0
wget -O go.tar.gz https://go.dev/dl/go$VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go.tar.gz && rm go.tar.gz
echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
echo 'export GO111MODULE=on' >> $HOME/.bash_profile
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
go version

echo -e '\n\e[42mInstalling required software\e[0m\n' && sleep 1

cd $HOME
rm -rf story

wget -O story-linux-amd64-0.9.11-2a25df1.tar.gz https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.9.11-2a25df1.tar.gz
tar xvf story-linux-amd64-0.9.11-2a25df1.tar.gz
sudo chmod +x story-linux-amd64-0.9.11-2a25df1/story
sudo mv story-linux-amd64-0.9.11-2a25df1/story /usr/local/bin/
story version

cd $HOME
rm -rf story-geth

wget -O geth-linux-amd64-0.9.2-ea9f0d2.tar.gz https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.2-ea9f0d2.tar.gz 
tar xvf geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
sudo chmod +x geth-linux-amd64-0.9.2-ea9f0d2/geth
sudo mv geth-linux-amd64-0.9.2-ea9f0d2/geth /usr/local/bin/story-geth

$EXEC_BINARY init --network iliad  --moniker "${MONIKER}"
sleep 1
$EXEC_BINARY validator export --export-evm-key --evm-key-path $HOME/.story/.env
$EXEC_BINARY validator export --export-evm-key >>$HOME/.story/story/config/wallet.txt
cat $HOME/.story/.env >>$HOME/.story/story/config/wallet.txt


sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF  
[Unit]
Description=Story Execution Layer
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/local/bin/story-geth --iliad --syncmode full
Restart=always
RestartSec=3
LimitNOFILE=infinity
LimitNPROC=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/$NODE_NAME.service > /dev/null <<EOF  
[Unit]
Description=Story Consensus Node
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/.story/story
ExecStart=/usr/local/bin/story run
Restart=always
RestartSec=3
LimitNOFILE=infinity
LimitNPROC=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF

echo -e '\n\e[42mOpening necessary ports and checking UFW rules\e[0m\n' && sleep 1
PORT_BASE=235  # New port base

# Open necessary ports in UFW if they are not already open
for port in ${PORT_BASE}56 ${PORT_BASE}57 ${PORT_BASE}58 ${PORT_BASE}17; do
    if sudo ufw status | grep -q "$port"; then
        echo -e "\e[32mPort $port is already open in UFW.\e[39m"
    else
        sudo ufw allow $port/tcp
        echo -e "\e[32mPort $port has been opened in UFW.\e[39m"
    fi
done

# Checking for port conflicts
if ss -tulpen | awk '{print $5}' | grep -q ":26656$" ; then
    echo -e "\e[31mPort 26656 is currently in use.\e[39m"
    sleep 2
    sed -i -e "s|:26656\"|:${PORT_BASE}56\"|g" $NODE_HOME/config/config.toml
    echo -e "\n\e[42mPort 26656 changed to ${PORT_BASE}56.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":26657$" ; then
    echo -e "\e[31mPort 26657 is currently in use.\e[39m"
    sleep 2
    sed -i -e "s|:26657\"|:${PORT_BASE}57\"|" $NODE_HOME/config/config.toml
    echo -e "\n\e[42mPort 26657 changed to ${PORT_BASE}57.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":26658$" ; then
    echo -e "\e[31mPort 26658 is currently in use.\e[39m"
    sleep 2
    sed -i -e "s|:26658\"|:${PORT_BASE}58\"|" $NODE_HOME/config/config.toml
    echo -e "\n\e[42mPort 26658 changed to ${PORT_BASE}58.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":1317$" ; then
    echo -e "\e[31mPort 1317 is currently in use.\e[39m"
    sleep 2
    sed -i -e "s|:1317\"|:${PORT_BASE}17\"|" $NODE_HOME/config/story.toml
    echo -e "\n\e[42mPort 1317 changed to ${PORT_BASE}17.\e[0m\n"
    sleep 2
fi

sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable $NODE_NAME
sudo systemctl restart $NODE_NAME
sudo systemctl enable story-geth
sudo systemctl restart story-geth
sleep 5

echo -e '\n\e[42mChecking node status\e[0m\n' && sleep 1
if [[ `service $NODE_NAME status | grep active` =~ "running" ]]; then
  echo -e "Your $NODE_NAME node \e[32mis installed and running!\e[39m"
  echo -e "You can check node status using \e[7mservice story status\e[0m"
  echo -e "Press \e[7mQ\e[0m to exit the status menu"
else
  echo -e "Your $NODE_NAME node \e[31mwas not installed correctly. Please try again.\e[39m"
fi
