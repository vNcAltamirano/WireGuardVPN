#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"
PEER_DIR="${PROJECT}/data/peers"

if [[ $# -ne 1 ]]; then
    echo "Uso:"
    echo "  sudo $0 <peer-name>"
    exit 1
fi

PEER_NAME="$1"
CONF="${PEER_DIR}/${PEER_NAME}.conf"

if [[ ! -f "$CONF" ]]; then
    echo "ERROR: no existe:"
    echo "  $CONF"
    exit 1
fi

echo
echo "======================================================"
echo " WireGuardVPN - QR"
echo " Peer: $PEER_NAME"
echo "======================================================"
echo

qrencode -t ansiutf8 < "$CONF"

echo
echo "======================================================"
echo "Escanear exclusivamente desde la app oficial WireGuard."
echo "======================================================"
