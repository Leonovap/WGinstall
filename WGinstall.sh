#!/bin/bash

# Root cheking
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (sudo bash WGinstall.sh)"
  exit
fi





# FUNCTIONS

# MENU FUNCTION
menu(){                 
while true; do

echo -e "-\n-\n-\n-"
echo -e "What do you want to do?\n(Enter just an option number(1..4))"
echo -e "1. Install WireGuard Server\n2. Uninstall WireGuard Server\n3. Generate new peer(client)\n4. Exit script"
read -p "Enter your choice: " MENU_PICK

case "$MENU_PICK" in  
 1) install_wg_deb ;;
 2) delete_wg ;;
 3) generate_peer;;
 4) echo "Exiting... ^_^"; exit 0 ;;
 *) echo "Invalid option, please try again!" ;;
 esac
done
}




# INSTALLATION
install_wg_deb(){
# Already installed wireguard cheked and delete
 if which wg ; then 
  echo "wireguard is already installed, do you want to delet it?(yes/no)"
  read -r input 
  input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
  
  if [ "$input" = "yes" ] ; then 
   delete_wg;
   menu
  elif [ "$input" = "no" ] ; then 
   menu  
  else
   echo "Invalid input, please enter yes or no! "
   menu
  fi

fi

# Package upgrade
echo "Updating system packages..."
 if ! sudo apt update && sudo apt upgrade -y
   then echo "System update failed."
 exit 1
 fi

# install wireguard
echo "Installing WireGuard..."
sudo apt install wireguard -y wireguard-tools
echo "Wireguard was successfully installed!"

# Wireguard Configuration
echo "Configuring WireGuard..."

 #Creating directories
mkdir -p /etc/wireguard/keys
mkdir -p /etc/wireguard/Clients
chmod 700 /etc/wireguard/keys

 # Open ipv4 forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sysctl -p 

 # Public and private key generating
wg genkey | tee /etc/wireguard/keys/server_privatekey | wg pubkey > /etc/wireguard/keys/server_publickey

 # Key read
SERVER_PUBLIC_KEY=$(sudo cat /etc/wireguard/keys/server_publickey)
SERVER_PRIVATE_KEY=$(sudo cat /etc/wireguard/keys/server_privatekey)

 # Set port and adreses 
echo -e "Enter the server port!\nIf you wand deafult port just press enter (deafult is 51820)"
read -p "Enter port" SERVER_PORT
if [ -z "$SERVER_PORT" ]; then
   SERVER_PORT="51820"
fi

SERVER_IP="10.11.12.1/24"
# Creating WireGuard server config wg0.conf
echo " Creating WireGuard server configuration... "
cat <<END | sudo tee /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_IP
ListenPort = $SERVER_PORT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
END
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
echo -e "WireGuard is installed and configurated!\nNow you can generate clients!"
}



# DELETE FUNCTION
delete_wg(){

   echo "Removing WireGuard..."
   # DISABLE SYSTEMD AND REMOVE BINARIES
   systemctl stop wg-quick@wg0.service
   systemctl disable wg-quick@wg0.service
   sudo apt purge -y --auto-remove wireguard wireguard-tools
   # DELETE FOLDERS KEYS AND FILES
   sudo rm -rf /etc/wireguard/keys
   sudo rm -rf /etc/wireguard/Clients
   sudo rm -rf /etc/wireguard
   # DISABLE IP4 FORWARDING
   sed -i 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/g' /etc/sysctl.conf
   sudo sysctl -p 
   # EXIT MESSAGES
   echo "WireGuard has been removed!" 
   echo -e "Please check and delete any remaining keys \n or config directories manually if needed.!" ;

  exit 0
}



# GENERATE PEER FUNCTION
generate_peer(){
# NAME ENTERING
read -p "Enter client name: " CLIENT_NAME

#Keys generating
wg genkey | tee /etc/wireguard/keys/"${CLIENT_NAME}_privkey" | wg pubkey | tee /etc/wireguard/keys/"${CLIENT_NAME}_pubkey" 

# VARIABLES FOR CONFIG 
SERVER_IP=$(sudo grep "Address " /etc/wireguard/wg0.conf | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $NF}' | awk -F '/' '{print $1}')
SERVER_PORT=$(sudo grep "ListenPort " /etc/wireguard/wg0.conf | awk '/[0-9]+/ {print $NF}')
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/keys/server_publickey)
LAST_PEER_IP=$(sudo grep "AllowedIPs " /etc/wireguard/wg0.conf | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $NF}' \
| sort -V | tail -n 1 | awk -F '.' '{print $1"."$2"."$3"."($4+1)}')
CLIENTS_PUBKEY=$(cat /etc/wireguard/keys/"${CLIENT_NAME}_pubkey")
CLIENTS_PRIVKEY=$(cat /etc/wireguard/keys/"${CLIENT_NAME}_privkey")
ENDPOINT=$(hostname -I | tr ' ' '\n' | grep -vE '^(10|172\.1[6-9]|172\.2[0-9]|172\.3[0-1]|192\.168|127)' | head -n 1)

# GENERATING NEW IP FOR THE NEW PEER
echo "Generating new IP address..."
if ! grep -q "AllowedIPs " /etc/wireguard/wg0.conf ; then
PEER_IP=$(echo "$SERVER_IP" |  awk -F '.' '{print $1"."$2"."$3"."($4+1)}')
else 
PEER_IP=$(echo "$LAST_PEER_IP")
fi
echo "NEW PEER IP IS : $PEER_IP !"

# EDITING WG0.CONF CONFIGURATION FILE
echo "Editing wg0.conf configuration file... "

cat <<END | sudo tee -a /etc/wireguard/wg0.conf
[Peer]
PublicKey = $CLIENTS_PUBKEY
AllowedIPs = $PEER_IP/24
END

# GENERATING PEER CONFIGURATION FILE
echo "Generating ${CLIENT_NAME}'s configuration file... "

cat <<END | sudo tee -a /etc/wireguard/Clients/"$CLIENT_NAME.conf"
[Interface]
PrivateKey = $CLIENTS_PRIVKEY
Address = $PEER_IP/32
DNS = 8.8.8.8
[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $ENDPOINT:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 20
END

# RESTART WG
systemctl restart wg-quick@wg0


  # TEST INFO
  # echo "SERVER IP IS: $SERVER_IP"
  # echo "CLIENTS PUBKEY IS: $CLIENTS_PUBKEY"
  # echo "CLIENTS PRIVKEY IS: $CLIENTS_PRIVKEY"
  # echo "SERVER PORT IS: $SERVER_PORT"
  # echo "SERVER PUBLIC KEY IS: $SERVER_PUBLIC_KEY"

}


echo "Welcome to WireGuard Manager"
menu ;



