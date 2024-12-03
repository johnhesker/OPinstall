#!/bin/bash

BASE="https://raw.githubusercontent.com/BlackIceNodeRunner/BlackIceGuides/main/base.sh"
source <(curl -s $BASE)
bold=$(tput bold)
normal=$(tput sgr0)

NODES_DIR="$HOME/ocean"

header "Reboot script initialized!"

while [ true ]; do
  cd $NODES_DIR
  for node in $(ls | grep ocean_); do
    reboot_time=`date +'Reboot started %d %B at %H:%M'`
    header "$reboot_time"
    cd $NODES_DIR/$node && docker compose down
    docker system prune -af
    docker compose up -d
  done
  cd $HOME
  header "Reboot completed!"
  sleep 5h
done
