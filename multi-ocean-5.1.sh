#!/bin/bash

BASE="https://raw.githubusercontent.com/BlackIceNodeRunner/BlackIceGuides/main/base.sh"
source <(curl -s $BASE)
bold=$(tput bold)
normal=$(tput sgr0)

# Path to files with keys
NODES_DIR="$HOME/ocean"
WALLETS="/$HOME/wallets.txt"

# Env
HTTP_API_PORT=10001
P2P_ipV4BindTcpPort=10002
P2P_ipV4BindWsPort=10003
P2P_ipV6BindTcpPort=10004
P2P_ipV6BindWsPort=10005
TYPESENSE_PORT=10006
P2P_ANNOUNCE_ADDRESS=`curl ipinfo.io/ip`


docker_compose_setup(){
    cat <<EOF > docker-compose.yml
services:
  ocean-node:
    image: oceanprotocol/ocean-node:latest
    pull_policy: always
    container_name: ocean-node_$node_count
    restart: on-failure
    ports:
      - "$HTTP_API_PORT:$HTTP_API_PORT"
      - "$P2P_ipV4BindTcpPort:$P2P_ipV4BindTcpPort"
      - "$P2P_ipV4BindWsPort:$P2P_ipV4BindWsPort"
      - "$P2P_ipV6BindTcpPort:$P2P_ipV6BindTcpPort"
      - "$P2P_ipV6BindWsPort:$P2P_ipV6BindWsPort"
    environment:
      PRIVATE_KEY: '$PRIVATE_KEY'
      RPCS: '{"23295":{"rpc":"https://testnet.sapphire.oasis.io","chainId":23295,"network":"oasis_saphire_testnet","chunkSize":100},"11155420":{"rpc":"https://sepolia.optimism.io","chainId":11155420,"network":"optimism-sepolia","chunkSize":100}}'
      DB_URL: 'http://typesense:8108/?apiKey=xyz'
      IPFS_GATEWAY: 'https://ipfs.io/'
      ARWEAVE_GATEWAY: 'https://arweave.net/'
#      LOAD_INITIAL_DDOS: ''
#      FEE_TOKENS: ''
#      FEE_AMOUNT: ''
#      ADDRESS_FILE: ''
#      NODE_ENV: ''
#      AUTHORIZED_DECRYPTERS: ''
#      OPERATOR_SERVICE_URL: ''
      INTERFACES: '["HTTP","P2P"]'
#      ALLOWED_VALIDATORS: ''
#      INDEXER_NETWORKS: '[]'
      ALLOWED_ADMINS: '["$ALLOWED_ADMINS"]'
#      INDEXER_INTERVAL: ''
      DASHBOARD: 'true'
#      RATE_DENY_LIST: ''
#      MAX_REQ_PER_SECOND: ''
#      MAX_CHECKSUM_LENGTH: ''
#      LOG_LEVEL: ''
      HTTP_API_PORT: '$HTTP_API_PORT'
      P2P_ENABLE_IPV4: 'true'
      P2P_ENABLE_IPV6: 'false'
      P2P_ipV4BindAddress: '0.0.0.0'
      P2P_ipV4BindTcpPort: '$P2P_ipV4BindTcpPort'
      P2P_ipV4BindWsPort: '$P2P_ipV4BindWsPort'
      P2P_ipV6BindAddress: '::'
      P2P_ipV6BindTcpPort: '$P2P_ipV6BindTcpPort'
      P2P_ipV6BindWsPort: '$P2P_ipV6BindWsPort'
      P2P_ANNOUNCE_ADDRESSES: '$P2P_ANNOUNCE_ADDRESSES'
#      P2P_ANNOUNCE_PRIVATE: ''
#      P2P_pubsubPeerDiscoveryInterval: ''
#      P2P_dhtMaxInboundStreams: ''
#      P2P_dhtMaxOutboundStreams: ''
#      P2P_mDNSInterval: ''
#      P2P_connectionsMaxParallelDials: ''
#      P2P_connectionsDialTimeout: ''
#      P2P_ENABLE_UPNP: ''
#      P2P_ENABLE_AUTONAT: ''
#      P2P_ENABLE_CIRCUIT_RELAY_SERVER: ''
#      P2P_ENABLE_CIRCUIT_RELAY_CLIENT: ''
#      P2P_BOOTSTRAP_NODES: ''
#      P2P_FILTER_ANNOUNCED_ADDRESSES: ''
    networks:
      - ocean_network
    depends_on:
      - typesense

  typesense:
    image: typesense/typesense:26.0
    container_name: typesense_$node_count
    ports:
#      - "8108:8108"
      - "$TYPESENSE_PORT:$TYPESENSE_PORT"
    networks:
      - ocean_network
    volumes:
      - typesense-data:/data
    command: '--data-dir /data --api-key=xyz'

volumes:
  typesense-data:
    driver: local

networks:
  ocean_network:
    driver: bridge
EOF
}


validate_hex() {
  if [[ ! "$1" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
    echo "The private key seems invalid, exiting ..."
    continue
  fi
}


validate_address() {
  if [[ ! "$1" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    echo "Invalid wallet address, exiting!"
    continue
  fi
}


validate_port() {
  if [[ ! "$1" =~ ^[0-9]+$ ]] || [ "$1" -le 1024 ] || [ "$1" -ge 65535 ]; then
    echo "Invalid port number, it must be between 1024 and 65535."
    continue
  fi
}


validate_ip_or_fqdn() {
  local input=$1

  if [[ "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -r -a octets <<< "$input"
    for octet in "${octets[@]}"; do
      if (( octet < 0 || octet > 255 )); then
        echo "Invalid IPv4 address. Each octet must be between 0 and 255."
        return 1
      fi
    done

    if [[ "$input" =~ ^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.|^169\.254\.|^100\.64\.|^198\.51\.100\.|^203\.0\.113\.|^224\.|^240\. ]]; then
      echo "The provided IP address belongs to a private or non-routable range and might not be accessible from other nodes."
      return 1
    fi
  elif [[ "$input" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    return 0
  else
    echo "Invalid input, must be a valid IPv4 address or FQDN."
    return 1
  fi

  return 0
}


# Shutdown docker compose and delete directories
delete_nodes() {
  cd $NODES_DIR
  for node in $(ls | grep ocean_); do
    cd $HOME/$node && docker compose down && docker system prune -af
  done
  cd $HOME
  rm -rf ocean/
}

# Reboot nodes
reboot_nodes() {
  cd $NODES_DIR
  for node in $(ls | grep ocean_); do
    cd $NODES_DIR/$node && docker compose down && docker system prune -af
  done
  cd $NODES_DIR
  sleep 5
  for node in $(ls | grep ocean_); do
    cd $NODES_DIR/$node && docker compose up -d
  done
}

#Stop nodes
stop_nodes() {
  cd $NODES_DIR
  for node in $(ls | grep ocean_); do
    cd $NODES_DIR/$node && docker compose down && docker system prune -af
  done
  cd $HOME
}


update_nodes() {
  cd $NODES_DIR
  for node in $(ls | grep ocean_); do
    cd $NODES_DIR/$node && docker compose down && docker system prune -af && docker compose pull
  done
  cd $NODES_DIR
  sleep 5
  for node in $(ls | grep ocean_); do
    cd $NODES_DIR/$node && docker compose up -d
  done
}


case $1 in
  install)
    logo
    header "Installing OCEAN Nodes"
    node_count=1
    cat wallets.txt | while read priv pub; do
        # Get wallet priv.key and address
        PRIVATE_KEY=$priv
        ALLOWED_ADMINS=$pub

        mkdir -p $NODES_DIR/ocean_${node_count} && cd $NODES_DIR/ocean_${node_count} && \
        echo -e "${bold} Directory for\e[1;32m Ocean_$node_count\e[0m ${bold}created!\e[0m"
        sleep 2

        # Validate env
        validate_hex "$PRIVATE_KEY"
        validate_address "$ALLOWED_ADMINS"
        validate_port "$HTTP_API_PORT"
        validate_port "$P2P_ipV4BindTcpPort"
        validate_port "$P2P_ipV4BindWsPort"
        validate_port "$P2P_ipV6BindTcpPort"
        validate_port "$P2P_ipV6BindWsPort"
        if [ -n "$P2P_ANNOUNCE_ADDRESS" ]; then
          validate_ip_or_fqdn "$P2P_ANNOUNCE_ADDRESS"
          if [ $? -ne 0 ]; then
            echo "Invalid address. Exiting!"
            exit 1
          fi

        if [[ "$P2P_ANNOUNCE_ADDRESS" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # IPv4
            P2P_ANNOUNCE_ADDRESSES='["/ip4/'$P2P_ANNOUNCE_ADDRESS'/tcp/'$P2P_ipV4BindTcpPort'", "/ip4/'$P2P_ANNOUNCE_ADDRESS'/ws/tcp/'$P2P_ipV4BindWsPort'"]'
          elif [[ "$P2P_ANNOUNCE_ADDRESS" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            # FQDN
            P2P_ANNOUNCE_ADDRESSES='["/dns4/'$P2P_ANNOUNCE_ADDRESS'/tcp/'$P2P_ipV4BindTcpPort'", "/dns4/'$P2P_ANNOUNCE_ADDRESS'/ws/tcp/'$P2P_ipV4BindWsPort'"]'
          fi
        else
          P2P_ANNOUNCE_ADDRESSES=''
          echo "No input provided, the Ocean Node might not be accessible from other nodes."
        fi

        # Creating directory and docker-compose files
        docker_compose_setup
        sleep 3

        # Annonce env
        echo -e "${bold}Allow and forward the following incoming TCP ports through the firewall to the Ocean Node host:"
        echo -e "${bold}HTTP API Port:\e[1;32m $HTTP_API_PORT\e[0m"
        echo -e "${bold}P2P IPv4 TCP Port:\e[1;32m $P2P_ipV4BindTcpPort\e[0m"
        echo -e "${bold}P2P IPv4 WebSocket Port:\e[1;32m $P2P_ipV4BindWsPort\e[0m"
        echo -e "${bold}P2P IPv6 TCP Port:\e[1;32m $P2P_ipV6BindTcpPort\e[0m"
        echo -e "${bold}P2P IPv6 WebSocket Port:\e[1;32m $P2P_ipV6BindWsPort\e[0m"
        echo -e "${bold}Typesense port:\e[1;32m $TYPESENSE_PORT\e[0m"
        sleep 3

        header "Starting Docker-compose"
        docker compose up -d
        sleep 20

        # Prepare for next loop
        node_count=$(( $node_count + 1 ))
        TYPESENSE_PORT=$(( TYPESENSE_PORT + 10 ))
        HTTP_API_PORT=$(( $HTTP_API_PORT + 10 ))
        P2P_ipV4BindTcpPort=$(( $P2P_ipV4BindTcpPort + 10 ))
        P2P_ipV4BindWsPort=$(( $P2P_ipV4BindWsPort + 10 ))
        P2P_ipV6BindTcpPort=$(( $P2P_ipV6BindTcpPort + 10 ))
        P2P_ipV6BindWsPort=$(( $P2P_ipV6BindWsPort + 10 ))
    done
    ;;

  uninstall)
    header "Uninstall nodes"
    delete_nodes
    ;;

  reboot)
    header "Rebooting nodes"
    reboot_nodes
    ;;

  stop)
    header "Stopping nodes"
    stop_nodes
    ;;

  update)
    header "Updating nodes"
    update_nodes
    ;;

  *)
    echo -e " ";
    echo -e "Invalid option!";
    echo -e "Usage: $0 <option>";
    echo -e " ";
    echo -e "Avalible options:";
    echo -e "install - install multiple Ocean Protocol nodes";
    echo -e "uninstall - delete all installed Ocean Protocol nodes";
    echo -e "reboot - reboot all Ocean Protocol nodes";
    echo -e "update - update all Ocean Protocol nodes"
    echo -e " ";
  ;;
esac