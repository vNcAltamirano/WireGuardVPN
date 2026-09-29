#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"

WG_IF="wg0"
WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_IF}.conf"

PEER_DIR="${WG_DIR}/peers"
EXPORT_DIR="${PROJECT}/data/peers"
INVENTORY="${EXPORT_DIR}/inventory.tsv"

SERVER_PUBLIC_KEY_FILE="${WG_DIR}/server_public.key"

VPN_PREFIX="10.8.0"
VPN_START=2
VPN_END=254

WG_PORT="51820"
WG_MTU="1360"

ALLOWED_IPS="10.8.0.0/24,192.168.2.0/24"

usage() {
    echo "Uso:"
    echo "  sudo $0 <peer-name> <endpoint>"
    echo
    echo "Ejemplo:"
    echo "  sudo $0 android-test-01 vpn.ecuavisa.com:51820"
}

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

PEER_NAME="$1"
ENDPOINT="$2"

if [[ ! "$PEER_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "ERROR: nombre de peer invalido"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

echo "======================================================"
echo " WireGuardVPN - ADD PEER"
echo "======================================================"
echo
echo "peer=$PEER_NAME"
echo "endpoint=$ENDPOINT"
echo

echo "===== 1. VALIDACIONES ====="

if ! systemctl is-active --quiet "wg-quick@${WG_IF}.service"; then
    echo "ERROR: wg0 no esta activo"
    exit 1
fi

if [[ ! -f "$SERVER_PUBLIC_KEY_FILE" ]]; then
    echo "ERROR: no existe server_public.key"
    exit 1
fi

install -d -m 700 -o root -g root "$PEER_DIR"

PROJECT_USER="$(stat -c '%U' "$PROJECT")"
PROJECT_GROUP="$(stat -c '%G' "$PROJECT")"

install -d     -m 700     -o "$PROJECT_USER"     -g "$PROJECT_GROUP"     "$EXPORT_DIR"

if [[ ! -f "$INVENTORY" ]]; then
    install         -m 600         -o "$PROJECT_USER"         -g "$PROJECT_GROUP"         /dev/null         "$INVENTORY"
else
    chown "$PROJECT_USER:$PROJECT_GROUP" "$INVENTORY"
    chmod 600 "$INVENTORY"
fi

PRIVATE_KEY="${PEER_DIR}/${PEER_NAME}.private.key"
PUBLIC_KEY="${PEER_DIR}/${PEER_NAME}.public.key"
PEER_CONF="${PEER_DIR}/${PEER_NAME}.conf"

EXPORT_CONF="${EXPORT_DIR}/${PEER_NAME}.conf"

if [[ -e "$PRIVATE_KEY" || -e "$PUBLIC_KEY" || -e "$PEER_CONF" ]]; then
    echo "ERROR: peer ya existe en /etc/wireguard/peers"
    exit 1
fi

if grep -q "^${PEER_NAME}[[:space:]]" "$INVENTORY" 2>/dev/null; then
    echo "ERROR: peer ya existe en inventario"
    exit 1
fi

echo "OK"

echo
echo "===== 2. BUSCAR IP LIBRE ====="

USED_IPS="$(
    {
        awk -F'\t' 'NF >= 2 {print $2}' "$INVENTORY" 2>/dev/null || true
        wg show "$WG_IF" allowed-ips 2>/dev/null |
            awk '{print $2}' |
            cut -d/ -f1
    } |
    sort -u
)"

PEER_IP=""

for n in $(seq "$VPN_START" "$VPN_END"); do

    CANDIDATE="${VPN_PREFIX}.${n}"

    if ! grep -qx "$CANDIDATE" <<<"$USED_IPS"; then
        PEER_IP="$CANDIDATE"
        break
    fi

done

if [[ -z "$PEER_IP" ]]; then
    echo "ERROR: no quedan IPs disponibles"
    exit 1
fi

echo "IP asignada: ${PEER_IP}/32"

echo
echo "===== 3. GENERAR CLAVES ====="

umask 077

wg genkey > "$PRIVATE_KEY"
wg pubkey < "$PRIVATE_KEY" > "$PUBLIC_KEY"

chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"

CLIENT_PRIVATE_KEY="$(cat "$PRIVATE_KEY")"
CLIENT_PUBLIC_KEY="$(cat "$PUBLIC_KEY")"
SERVER_PUBLIC_KEY="$(cat "$SERVER_PUBLIC_KEY_FILE")"

echo "PublicKey cliente:"
echo "$CLIENT_PUBLIC_KEY"

echo
echo "===== 4. AGREGAR PEER EN VIVO ====="

wg set "$WG_IF" peer "$CLIENT_PUBLIC_KEY" allowed-ips "${PEER_IP}/32"

echo "OK"

echo
echo "===== 5. PERSISTIR PEER EN wg0.conf ====="

cat >> "$WG_CONF" <<EOF_CONF

# ------------------------------------------------------------
# Peer: ${PEER_NAME}
# ------------------------------------------------------------
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${PEER_IP}/32
EOF_CONF

chmod 600 "$WG_CONF"

echo "OK"

echo
echo "===== 6. GENERAR PERFIL CLIENTE ====="

cat > "$PEER_CONF" <<EOF_CLIENT
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${PEER_IP}/32
MTU = ${WG_MTU}

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${ENDPOINT}
AllowedIPs = ${ALLOWED_IPS}
PersistentKeepalive = 25
EOF_CLIENT

chmod 600 "$PEER_CONF"

install     -m 600     -o "$PROJECT_USER"     -g "$PROJECT_GROUP"     "$PEER_CONF"     "$EXPORT_CONF"

echo "OK"

echo
echo "===== 7. INVENTARIO ====="

CREATED_AT="$(date -Is)"

printf '%s\t%s\t%s\t%s\t%s\n' \
    "$PEER_NAME" \
    "$PEER_IP" \
    "$CLIENT_PUBLIC_KEY" \
    "$CREATED_AT" \
    "active" \
    >> "$INVENTORY"

echo "OK"

echo
echo "===== 8. VALIDACION ====="

wg show "$WG_IF" peer "$CLIENT_PUBLIC_KEY"

echo
echo "======================================================"
echo " PEER CREADO"
echo "======================================================"
echo
echo "Name:"
echo "  $PEER_NAME"
echo
echo "VPN IP:"
echo "  ${PEER_IP}/32"
echo
echo "PublicKey:"
echo "  $CLIENT_PUBLIC_KEY"
echo
echo "Perfil:"
echo "  $EXPORT_CONF"
echo
echo "QR:"
echo "  sudo /srv/WireGuardVPN/scripts/peer_qr.sh $PEER_NAME"
echo
echo "IMPORTANTE:"
echo "  El archivo .conf contiene la clave privada del cliente."
echo "  No subirlo a Git."
echo "======================================================"
