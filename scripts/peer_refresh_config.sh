#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"

WG_DIR="/etc/wireguard"
SECRET_DIR="${WG_DIR}/peers"

META_DIR="${PROJECT}/config/peers"
ROLES_DIR="${PROJECT}/config/roles"
EXPORT_DIR="${PROJECT}/data/peers"

DNS_SERVER="192.168.2.10"
WG_MTU="1360"

usage() {
    echo "Uso:"
    echo "  sudo $0 <peer-name> <endpoint>"
}

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

PEER="$1"
ENDPOINT="$2"

META="${META_DIR}/${PEER}.meta"
PRIVATE_KEY="${SECRET_DIR}/${PEER}.private.key"
OPERATIVE_CONF="${SECRET_DIR}/${PEER}.conf"
EXPORT_CONF="${EXPORT_DIR}/${PEER}.conf"
SERVER_PUBLIC="${WG_DIR}/server_public.key"

if [[ ! -f "$META" ]]; then
    echo "ERROR: metadata no encontrada"
    exit 1
fi

if [[ ! -f "$PRIVATE_KEY" ]]; then
    echo "ERROR: private key no encontrada"
    exit 1
fi

unset NAME VPN_IP ROLE ENABLED

# shellcheck disable=SC1090
source "$META"

if [[ "${ENABLED:-no}" != "yes" ]]; then
    echo "ERROR: peer no habilitado"
    exit 1
fi

ROLE_FILE="${ROLES_DIR}/${ROLE}.conf"

if [[ ! -f "$ROLE_FILE" ]]; then
    echo "ERROR: rol inexistente: $ROLE"
    exit 1
fi

unset DNS_ACCESS ALLOWED_IPS

# shellcheck disable=SC1090
source "$ROLE_FILE"

DNS_ACCESS="${DNS_ACCESS:-no}"
ALLOWED_IPS="${ALLOWED_IPS:-}"

if [[ -z "$ALLOWED_IPS" ]]; then
    ALLOWED_IPS="10.8.0.1/32"
fi

CLIENT_PRIVATE="$(cat "$PRIVATE_KEY")"
SERVER_PUBLIC_KEY="$(cat "$SERVER_PUBLIC")"

umask 077

{
    echo "[Interface]"
    echo "PrivateKey = ${CLIENT_PRIVATE}"
    echo "Address = ${VPN_IP}/32"
    echo "MTU = ${WG_MTU}"

    if [[ "$DNS_ACCESS" == "yes" ]]; then
        echo "DNS = ${DNS_SERVER}"
    fi

    echo
    echo "[Peer]"
    echo "PublicKey = ${SERVER_PUBLIC_KEY}"
    echo "Endpoint = ${ENDPOINT}"
    echo "AllowedIPs = ${ALLOWED_IPS}"
    echo "PersistentKeepalive = 25"

} > "$OPERATIVE_CONF"

chmod 600 "$OPERATIVE_CONF"

PROJECT_USER="$(stat -c '%U' "$PROJECT")"
PROJECT_GROUP="$(stat -c '%G' "$PROJECT")"

install \
    -m 600 \
    -o "$PROJECT_USER" \
    -g "$PROJECT_GROUP" \
    "$OPERATIVE_CONF" \
    "$EXPORT_CONF"

echo "======================================================"
echo " WireGuardVPN - CLIENT CONFIG REFRESHED"
echo "======================================================"
echo
echo "Peer:"
echo "  $PEER"
echo
echo "Role:"
echo "  $ROLE"
echo
echo "AllowedIPs:"
echo "  $ALLOWED_IPS"
echo
echo "DNS:"
if [[ "$DNS_ACCESS" == "yes" ]]; then
    echo "  $DNS_SERVER"
else
    echo "  none"
fi
echo
echo "Perfil:"
echo "  $EXPORT_CONF"
echo
echo "QR:"
echo "  sudo ${PROJECT}/scripts/peer_qr.sh $PEER"
echo
echo "IMPORTANTE:"
echo "  Debe volver a importarse el perfil en el cliente"
echo "  para que cambien DNS/AllowedIPs."
echo "======================================================"
