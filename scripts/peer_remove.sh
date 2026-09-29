#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"

WG_IF="wg0"
WG_CONF="/etc/wireguard/wg0.conf"

PEER_SECRET_DIR="/etc/wireguard/peers"
EXPORT_DIR="${PROJECT}/data/peers"
META_DIR="${PROJECT}/config/peers"
INVENTORY="${EXPORT_DIR}/inventory.tsv"

usage() {
    echo "Uso:"
    echo "  sudo $0 <peer-name>"
}

if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

PEER_NAME="$1"

PUBLIC_KEY_FILE="${PEER_SECRET_DIR}/${PEER_NAME}.public.key"
PRIVATE_KEY_FILE="${PEER_SECRET_DIR}/${PEER_NAME}.private.key"
OPERATIVE_CONF="${PEER_SECRET_DIR}/${PEER_NAME}.conf"

EXPORT_CONF="${EXPORT_DIR}/${PEER_NAME}.conf"
META_FILE="${META_DIR}/${PEER_NAME}.meta"

echo "======================================================"
echo " WireGuardVPN - REMOVE PEER"
echo "======================================================"
echo
echo "peer=$PEER_NAME"
echo

echo "===== 1. VALIDAR PEER ====="

if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
    echo "ERROR: no existe:"
    echo "  $PUBLIC_KEY_FILE"
    exit 1
fi

PUBLIC_KEY="$(cat "$PUBLIC_KEY_FILE")"

if [[ -z "$PUBLIC_KEY" ]]; then
    echo "ERROR: public key vacia"
    exit 1
fi

echo "PublicKey:"
echo "$PUBLIC_KEY"

echo
echo "===== 2. ELIMINAR PEER LIVE ====="

if wg show "$WG_IF" peers | grep -qx "$PUBLIC_KEY"; then
    wg set "$WG_IF" peer "$PUBLIC_KEY" remove
    echo "OK: eliminado del kernel"
else
    echo "INFO: peer no estaba cargado en wg0"
fi

echo
echo "===== 3. ELIMINAR DE wg0.conf ====="

python3 - "$WG_CONF" "$PEER_NAME" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
peer = sys.argv[2]

lines = path.read_text().splitlines()

marker = f"# Peer: {peer}"

out = []
i = 0
removed = False

while i < len(lines):

    # Nuestros bloques comienzan:
    #
    # # ------------------------------------------------------------
    # # Peer: NAME
    #
    if (
        lines[i].strip() == "# ------------------------------------------------------------"
        and i + 1 < len(lines)
        and lines[i + 1].strip() == marker
    ):
        removed = True
        i += 2

        # Consumir Role/commentarios/[Peer]/PublicKey/AllowedIPs
        # hasta el proximo separador de peer o EOF.
        while i < len(lines):
            if (
                lines[i].strip() == "# ------------------------------------------------------------"
                and i + 1 < len(lines)
                and lines[i + 1].strip().startswith("# Peer:")
            ):
                break

            i += 1

        continue

    out.append(lines[i])
    i += 1

path.write_text("\n".join(out).rstrip() + "\n")

print("removed=yes" if removed else "removed=no")
PY

chmod 600 "$WG_CONF"

echo
echo "===== 4. REVOCAR EN INVENTARIO ====="

if [[ -f "$INVENTORY" ]]; then

    PROJECT_USER="$(stat -c '%U' "$PROJECT")"
    PROJECT_GROUP="$(stat -c '%G' "$PROJECT")"

    TMP="$(mktemp)"

    awk -F'\t' -v OFS='\t' -v peer="$PEER_NAME" '
        {
            if ($1 == peer && $5 == "active") {
                $5 = "revoked"
            }
            print
        }
    ' "$INVENTORY" > "$TMP"

    install \
        -m 600 \
        -o "$PROJECT_USER" \
        -g "$PROJECT_GROUP" \
        "$TMP" \
        "$INVENTORY"

    rm -f "$TMP"

    echo "OK"

else
    echo "INFO: inventory.tsv no existe"
fi

echo
echo "===== 5. ELIMINAR METADATA ACTIVA ====="

if [[ -f "$META_FILE" ]]; then
    rm -f "$META_FILE"
    echo "OK: $META_FILE"
else
    echo "INFO: metadata no encontrada"
fi

echo
echo "===== 6. DESTRUIR MATERIAL CLIENTE ====="

rm -f \
    "$PRIVATE_KEY_FILE" \
    "$PUBLIC_KEY_FILE" \
    "$OPERATIVE_CONF" \
    "$EXPORT_CONF"

echo "OK"

echo
echo "===== 7. REGENERAR FIREWALL ====="

"${PROJECT}/scripts/firewall_apply.sh"

echo
echo "===== 8. VALIDAR ====="

if wg show "$WG_IF" peers | grep -qx "$PUBLIC_KEY"; then
    echo "ERROR: peer todavia existe en wg0"
    exit 1
else
    echo "OK: peer no existe en wg0"
fi

if [[ -e "$META_FILE" ]]; then
    echo "ERROR: metadata todavia existe"
    exit 1
else
    echo "OK: metadata eliminada"
fi

if [[ -e "$PRIVATE_KEY_FILE" || -e "$OPERATIVE_CONF" || -e "$EXPORT_CONF" ]]; then
    echo "ERROR: quedaron secretos/perfiles del peer"
    exit 1
else
    echo "OK: material cliente eliminado"
fi

echo
echo "======================================================"
echo " PEER REVOCADO"
echo "======================================================"
echo
echo "Name:"
echo "  $PEER_NAME"
echo
echo "Estado inventario:"
echo "  revoked"
echo
echo "La IP VPN queda disponible para futuras altas."
echo "======================================================"
