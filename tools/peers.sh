#!/usr/bin/env bash
set -u

INVENTORY="/srv/WireGuardVPN/data/peers/inventory.tsv"

echo "======================================================"
echo " WireGuardVPN - PEERS"
echo "======================================================"
echo

if [[ ! -f "$INVENTORY" ]]; then
    echo "No existe inventario."
    exit 0
fi

printf "%-25s %-15s %-45s %-25s %-10s\n" \
    "NAME" \
    "VPN IP" \
    "PUBLIC KEY" \
    "CREATED" \
    "STATUS"

printf '%*s\n' 125 '' | tr ' ' '-'

while IFS=$'\t' read -r name ip pub created status; do

    [[ -z "$name" ]] && continue

    printf "%-25s %-15s %-45s %-25s %-10s\n" \
        "$name" \
        "$ip" \
        "$pub" \
        "$created" \
        "$status"

done < "$INVENTORY"

echo
echo "===== LIVE WIREGUARD ====="
sudo wg show
