#!/usr/bin/env bash

set -u

echo "======================================================"
echo " WireGuardVPN - NETWORK INFO"
echo "======================================================"

echo
echo "HOST"
hostname

echo
echo "INTERFACES"
ip -br addr

echo
echo "ROUTING"
ip route

echo
echo "IP FORWARDING"
sysctl net.ipv4.ip_forward

echo
echo "WIREGUARD"
if command -v wg >/dev/null 2>&1; then
    sudo wg show
else
    echo "wireguard-tools no instalado"
fi

echo
echo "UDP 51820"
sudo ss -lunp | grep ':51820 ' || echo "51820/UDP libre"

echo
echo "======================================================"
