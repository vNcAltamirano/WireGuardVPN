#!/usr/bin/env bash
set -u

echo "======================================================"
echo " WireGuardVPN - STATUS"
echo "======================================================"

echo
echo "[HOST]"
hostname

echo
echo "[WG SERVICE]"

WG_ENABLED="$(systemctl is-enabled wg-quick@wg0.service 2>/dev/null || true)"
WG_ACTIVE="$(systemctl is-active wg-quick@wg0.service 2>/dev/null || true)"

echo "enabled=${WG_ENABLED:-not-installed}"
echo "active=${WG_ACTIVE:-inactive}"

echo
echo "[WG INTERFACE]"
if ip link show wg0 >/dev/null 2>&1; then
    ip -br addr show wg0
else
    echo "wg0 no existe"
fi

echo
echo "[WIREGUARD]"
if command -v wg >/dev/null 2>&1; then
    sudo wg show
else
    echo "wireguard-tools no instalado"
fi

echo
echo "[FORWARDING]"
sysctl net.ipv4.ip_forward

echo
echo "[PORT]"
sudo ss -lunp | grep ':51820' || echo "51820/UDP no escuchando"

echo
echo "[WIREGUARD DIR]"
if [[ -d /etc/wireguard ]]; then
    sudo ls -ld /etc/wireguard
else
    echo "/etc/wireguard no existe"
fi

echo
echo "======================================================"
