#!/bin/bash

# Root cheking
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (sudo bash WGinstall.sh)"
  exit
fi
# FUNCTIONS

# Menu function
menu(){                 
while true; do

echo -e "What do you want to do?\n(Enter just an option number(1..4))"
echo -e "1. Install WireGuard Server\n2. Uninstall WireGuard Server\n3. Generate new peer(client)\n4. Exit script"
read -p "Enter your choice: " MENU_PICK

case "$MENU_PICK" in  
 1) install_wg ;;
 2) delete_wg ;;
 3) echo "generating peer..." ;;
 4) echo "Exiting... ^_^"; exit 0 ;;
 *) echo "Invalid option, please try again!" ;;
 esac
done
}

# Instalation function
install_wg(){
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
echo "Enter the server port! "
echo "If you wand deafult port just press enter (deafult is 51820)"
read -p "Enter port" SERVER_PORT
if [ -z "$SERVER_PORT" ]; then
   SERVER_PORT="51820"
fi

SERVER_IP="10.8.0.1/24"
# Creating WireGuard server config wg0.conf
echo " Creating WireGuard server configuration... "
cat <<END | sudo tee /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_IP
ListenPort = $SERVER_PORT
SaveConfig = true
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
END
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
echo -e "WireGuard is installed and configurated!\nNow you can generate clients!"
}

# Delete function
delete_wg(){

   echo "Removing WireGuard..."
   systemctl stop wg-quick@wg0.service
   systemctl disable wg-quick@wg0.service
   sudo apt purge -y --auto-remove wireguard wireguard-tools
   rm -rf /etc/wireguard/keys
   rm -rf /etc/wireguard
   sed -i 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/g' /etc/sysctl.conf
   sudo sysctl -p 
   echo "WireGuard has been removed!" 
   echo -e "Please check and delete any remaining keys \n or config directories manually if needed.!" ;

  exit 0
}




echo "Welcome to WireGuard Manager"
menu ;



