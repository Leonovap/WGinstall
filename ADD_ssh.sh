#!/bin/bash

menu(){                 
while true; do

echo -e "Welcome to simple SSH key manager!"
echo -e "What do you want to do?\n(Enter just an option number"
echo -e "1. Generate SSH KEY\n2. ADD KEY TO YOUR SERVER\n3. EXIT"
read -p "Enter your choice: " MENU_PICK

case "$MENU_PICK" in  
 1) server_key_generate ;;
 2) add_key_to_server ;;
 3) echo "Exiting... ^_^"; exit 0 ;;
 *) echo "Invalid option, please try again!" ;;
 esac
done
}

# FAST GENERATE KEY 
server_key_generate(){

read -p "ENTER YOUR EMAIL" EMAIL
ssh-keygen -t ed25519 -C "$EMAIL"

}



# ADD KEY TO SERVER FUNCTION
add_key_to_server(){

read -p "Enter the server IP... " SERVER_IP
read -p "Enter the server LOGIN NAME... " SERVER_LOGIN
cat ~/.ssh/id_ed25519.pub | ssh ${SERVER_IP}@${SERVER_USER} "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
exit 0

}
