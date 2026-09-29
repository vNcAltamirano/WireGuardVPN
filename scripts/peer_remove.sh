#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"

WG_IF="wg0"
WG_CONF="/etc/wireguard/wg0.conf"

PEER_DIR="/etc/wireguard/peers"
EXPORT_DIR="${PROJECT}/data/peers"
INVENTORY="${EXPORT_DIR}/inventory.tsv"

if [[ $# -ne 1 ]]; then
    echo "Uso:"
    echo "  sudo $0 <peer-name>"
    exit 1
fi

PEER_NAME="$1"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

PUBLIC_KEY_FILE="${PEER_DIR}/${PEER_NAME}.public.key"

if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
    echo "ERROR: peer no encontrado"
    exit 1
fi

PUBLIC_KEY="$(cat "$PUBLIC_KEY_FILE")"

echo "======================================================"
echo " WireGuardVPN - REMOVE PEER"
echo "======================================================"
echo
echo "peer=$PEER_NAME"
echo "public_key=$PUBLIC_KEY"
echo

echo "===== 1. ELIMINAR PEER EN VIVO ====="

wg set "$WG_IF" peer "$PUBLIC_KEY" remove

echo "OK"

echo
echo "===== 2. ELIMINAR BLOQUE EN wg0.conf ====="

python3 - "$WG_CONF" "$PEER_NAME" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
peer = sys.argv[2]

text = path.read_text()

marker = f"# Peer: {peer}"

lines = text.splitlines()
out = []

i = 0

while i < len(lines):
    if lines[i].strip() == "# ------------------------------------------------------------":
        if i + 1 < len(lines) and lines[i + 1].strip() == marker:
            i += 1

            while i < len(lines):
                if (
                    i + 1 < len(lines)
                    and lines[i].strip() == "# ------------------------------------------------------------"
                    and lines[i + 1].startswith("# Peer:")
                ):
                    break

                i += 1

            continue

    out.append(lines[i])
    i += 1

path.write_text("\n".join(out).rstrip() + "\n")
PY

chmod 600 "$WG_CONF"

echo "OK"

echo
echo "===== 3. MARCAR INVENTARIO ====="

if [[ -f "$INVENTORY" ]]; then

    TMP="$(mktemp)"

    awk -F'\t' -v OFS='\t' -v peer="$PEER_NAME" '
    {
        if ($1 == peer) {
            $5 = "revoked"
        }
        print
    }
    ' "$INVENTORY" > "$TMP"

    install -m 600 "$TMP" "$INVENTORY"

    rm -f "$TMP"

fi

echo "OK"

echo
echo "===== 4. BORRAR SECRETOS CLIENTE ====="

rm -f \
    "${PEER_DIR}/${PEER_NAME}.private.key" \
    "${PEER_DIR}/${PEER_NAME}.public.key" \
    "${PEER_DIR}/${PEER_NAME}.conf" \
    "${EXPORT_DIR}/${PEER_NAME}.conf"

echo "OK"

echo
echo "======================================================"
echo " PEER REVOCADO"
echo "======================================================"
