#!/usr/bin/env bash
set -u

PROJECT="/srv/WireGuardVPN"

echo "======================================================"
echo " WireGuardVPN - ACCESS STATUS"
echo "======================================================"
echo

for file in "$PROJECT"/config/peers/*.meta; do

    [[ -e "$file" ]] || continue

    unset NAME VPN_IP ROLE ENABLED

    source "$file"

    printf "%-24s %-14s %-15s %-8s\n" \
        "${NAME:-unknown}" \
        "${VPN_IP:-unknown}" \
        "${ROLE:-none}" \
        "${ENABLED:-no}"

done

echo
echo "===== WIREGUARD LIVE ====="
sudo wg show

echo
echo "===== WG INPUT ====="
sudo iptables -L WG-INPUT -n -v

echo
echo "===== WG FORWARD ====="
sudo iptables -L WG-FORWARD -n -v
