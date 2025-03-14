#!/bin/bash

# test script to find IP in wg installer

LAST_PEER_IP=$(sudo grep "AllowedIPs " /etc/wireguard/wg0.conf | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $NF}' \
| sort -V | tail -n 1 | awk -F '.' '{print $1"."$2"."$3"."($4+1)}')
SERVER_IP=$(sudo grep "Address " /etc/wireguard/wg0.conf \
| awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $NF}' | awk -F '/' '{print $1}')



if ! grep "AllowedIPs " /etc/wireguard/wg0.conf ; then
PEER_IP=$(echo "$SERVER_IP" |  awk -F '.' '{print $1"."$2"."$3"."($4+1)}')
else 
PEER_IP=("${LAST_PEER_IP}")
fi


echo "PEER IP IS: $PEER_IP"
