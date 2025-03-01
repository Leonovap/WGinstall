#!/bin/bash

# Root cheking
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (sudo bash WGinstall.sh)"
  exit
fi



# Already installed wireguard cheked and delete
if which wg ; then 
  echo "wireguard is already installed, do you want to delet it?(yes/no)"
  read -r input 
  input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
  
  if [ "$input" = "yes" ] ; then 
   sudo apt purge -y --auto-remove wireguard wireguard-tools
   rm -rf /etc/wireguard
   sed -i 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/g' /etc/sysctl.conf
   sudo sysctl -p 
   echo "WireGuard has been removed!" 
   echo "Please check and delete any remaining keys or config directories manually if needed.!"
   exit 0
  elif [ "$input" = "no" ] ; then 
   echo "Exit script"
   exit 0  
  else
   echo "Invalid input, please enter yes or no! "
   exit 1
  fi

fi



# Package upgrade
if ! sudo apt update && sudo apt upgrade -y
   then echo "System can't update"
exit 1
fi



# install wireguard
sudo apt install wireguard
echo "Wireguard was successfully installed!"


# Wireguard Configuration

# Open ipv4 forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sysctl -p 
# Public and private key generating
wg genkey | tee /etc/wireguard/server_privatekey | wg pubkey > /etc/wireguard/server_publickey


