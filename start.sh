#!/bin/bash

BASE="https://raw.githubusercontent.com/BlackIceValidator/BlackIceGuides/refs/heads/main/base.sh"
source <(curl -s $BASE)
bold=$(tput bold)
normal=$(tput sgr0)

logo

if [[ !(-f multi-ocean.sh) ]]; then
    echo -e "Can't find base script file! Exiting"
    exit
fi

sleep 2
header "Installing requirements"
system_update
install_requirements
sudo apt install python3-pip -y
sudo pip install -r requirements.txt

remoove_old_docker
install_docker

header "Creating Wallets"
echo " "
python3 create_wallets.py

header "Starting installation"
./multi-ocean.sh install
