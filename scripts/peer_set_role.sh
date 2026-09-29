#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"

META_DIR="${PROJECT}/config/peers"
ROLES_DIR="${PROJECT}/config/roles"
FIREWALL="${PROJECT}/scripts/firewall_apply.sh"

usage() {
    echo "Uso:"
    echo "  sudo $0 <peer-name> <role>"
    echo
    echo "Roles:"
    find "$ROLES_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' \
        -printf '  %f\n' |
        sed 's/\.conf$//' |
        sort
}

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

PEER_NAME="$1"
NEW_ROLE="$2"

META="${META_DIR}/${PEER_NAME}.meta"
ROLE_FILE="${ROLES_DIR}/${NEW_ROLE}.conf"

if [[ ! -f "$META" ]]; then
    echo "ERROR: peer activo no encontrado:"
    echo "  $PEER_NAME"
    exit 1
fi

if [[ ! -f "$ROLE_FILE" ]]; then
    echo "ERROR: rol inexistente:"
    echo "  $NEW_ROLE"
    usage
    exit 1
fi

unset NAME VPN_IP ROLE ENABLED

# shellcheck disable=SC1090
source "$META"

NAME="${NAME:-}"
VPN_IP="${VPN_IP:-}"
OLD_ROLE="${ROLE:-none}"
ENABLED="${ENABLED:-no}"

if [[ "$ENABLED" != "yes" ]]; then
    echo "ERROR: peer no esta habilitado"
    exit 1
fi

if [[ -z "$NAME" || -z "$VPN_IP" ]]; then
    echo "ERROR: metadata incompleta"
    exit 1
fi

PROJECT_USER="$(stat -c '%U' "$PROJECT")"
PROJECT_GROUP="$(stat -c '%G' "$PROJECT")"

TMP="$(mktemp)"

cat > "$TMP" <<EOF_META
NAME=${NAME}
VPN_IP=${VPN_IP}
ROLE=${NEW_ROLE}
ENABLED=yes
EOF_META

install \
    -m 644 \
    -o "$PROJECT_USER" \
    -g "$PROJECT_GROUP" \
    "$TMP" \
    "$META"

rm -f "$TMP"

echo "======================================================"
echo " WireGuardVPN - ROLE CHANGE"
echo "======================================================"
echo
echo "Peer:"
echo "  $NAME"
echo
echo "VPN IP:"
echo "  $VPN_IP"
echo
echo "Old role:"
echo "  $OLD_ROLE"
echo
echo "New role:"
echo "  $NEW_ROLE"
echo

"$FIREWALL"

echo
echo "======================================================"
echo " ROLE UPDATED"
echo "======================================================"
