#!/bin/bash
# Root cheking
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (sudo bash WGinstall.sh)"
  exit
fi



# Already installed wireguard cheked and delete
if which wg ; then 
  echo "wireguard is already installed, do you want to delet it?(yes/no)"
  read input 
  if [ "$input" = "yes" ] ; then 
   sudo apt purge -y --auto-remove wireguard wireguard-tools
   echo "Wireguard packeges was deleted!" 
   echo "Please check and delete if you need keys and configs directorys!"
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
echo "Wireguard was successfylly installed!"



