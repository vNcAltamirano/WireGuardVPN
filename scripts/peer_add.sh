#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"

WG_IF="wg0"
WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_IF}.conf"

PEER_SECRET_DIR="${WG_DIR}/peers"
EXPORT_DIR="${PROJECT}/data/peers"
INVENTORY="${EXPORT_DIR}/inventory.tsv"

PEERS_META_DIR="${PROJECT}/config/peers"
ROLES_DIR="${PROJECT}/config/roles"

SERVER_PUBLIC_KEY_FILE="${WG_DIR}/server_public.key"

VPN_PREFIX="10.8.0"
VPN_START=2
VPN_END=254

WG_MTU="1360"
DNS_SERVER="192.168.2.10"

usage() {
    echo "Uso:"
    echo "  sudo $0 <peer-name> <endpoint> <role>"
    echo
    echo "Ejemplo:"
    echo "  sudo $0 android-reportero-02 ebc.vnc.homes:51820 reportero"
    echo
    echo "Roles disponibles:"
    find "$ROLES_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' \
        -printf '  %f\n' 2>/dev/null |
        sed 's/\.conf$//' |
        sort || true
}

if [[ $# -ne 3 ]]; then
    usage
    exit 1
fi

PEER_NAME="$1"
ENDPOINT="$2"
ROLE="$3"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

if [[ ! "$PEER_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "ERROR: nombre de peer invalido"
    exit 1
fi

ROLE_FILE="${ROLES_DIR}/${ROLE}.conf"

if [[ ! -f "$ROLE_FILE" ]]; then
    echo "ERROR: rol inexistente: $ROLE"
    usage
    exit 1
fi

echo "======================================================"
echo " WireGuardVPN - ADD PEER"
echo "======================================================"
echo
echo "peer=$PEER_NAME"
echo "endpoint=$ENDPOINT"
echo "role=$ROLE"
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

install -d -m 700 -o root -g root "$PEER_SECRET_DIR"

PROJECT_USER="$(stat -c '%U' "$PROJECT")"
PROJECT_GROUP="$(stat -c '%G' "$PROJECT")"

install -d \
    -m 700 \
    -o "$PROJECT_USER" \
    -g "$PROJECT_GROUP" \
    "$EXPORT_DIR"

install -d \
    -m 755 \
    -o "$PROJECT_USER" \
    -g "$PROJECT_GROUP" \
    "$PEERS_META_DIR"

if [[ ! -f "$INVENTORY" ]]; then
    install \
        -m 600 \
        -o "$PROJECT_USER" \
        -g "$PROJECT_GROUP" \
        /dev/null \
        "$INVENTORY"
else
    chown "$PROJECT_USER:$PROJECT_GROUP" "$INVENTORY"
    chmod 600 "$INVENTORY"
fi

PRIVATE_KEY="${PEER_SECRET_DIR}/${PEER_NAME}.private.key"
PUBLIC_KEY="${PEER_SECRET_DIR}/${PEER_NAME}.public.key"
PEER_CONF="${PEER_SECRET_DIR}/${PEER_NAME}.conf"

EXPORT_CONF="${EXPORT_DIR}/${PEER_NAME}.conf"
META_FILE="${PEERS_META_DIR}/${PEER_NAME}.meta"

if [[ -e "$PRIVATE_KEY" || -e "$PUBLIC_KEY" || -e "$PEER_CONF" ]]; then
    echo "ERROR: peer ya existe en /etc/wireguard/peers"
    exit 1
fi

if [[ -e "$META_FILE" ]]; then
    echo "ERROR: ya existe metadata para $PEER_NAME"
    exit 1
fi

if awk -F'\t' -v peer="$PEER_NAME" '$1 == peer {found=1} END{exit !found}' "$INVENTORY"; then
    echo "ERROR: peer ya existe en inventario"
    exit 1
fi

echo "OK"

echo
echo "===== 2. CARGAR ROL ====="

unset SERVER_ACCESS DNS_ACCESS SERVICES NETWORKS ALLOWED_IPS

# shellcheck disable=SC1090
source "$ROLE_FILE"

SERVER_ACCESS="${SERVER_ACCESS:-no}"
DNS_ACCESS="${DNS_ACCESS:-no}"
SERVICES="${SERVICES:-}"
NETWORKS="${NETWORKS:-}"
ALLOWED_IPS="${ALLOWED_IPS:-}"

if [[ -z "$ALLOWED_IPS" && "$ROLE" != "none" ]]; then
    echo "ERROR: rol $ROLE no define ALLOWED_IPS"
    exit 1
fi

echo "server_access=$SERVER_ACCESS"
echo "dns_access=$DNS_ACCESS"
echo "allowed_ips=${ALLOWED_IPS:-none}"

echo
echo "===== 3. BUSCAR IP LIBRE ====="

USED_IPS="$(
    {
        awk -F'\t' 'NF >= 5 && $5 == "active" {print $2}' "$INVENTORY" 2>/dev/null || true

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
echo "===== 4. GENERAR CLAVES ====="

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
echo "===== 5. AGREGAR PEER EN VIVO ====="

wg set "$WG_IF" \
    peer "$CLIENT_PUBLIC_KEY" \
    allowed-ips "${PEER_IP}/32"

echo "OK"

echo
echo "===== 6. PERSISTIR EN wg0.conf ====="

cat >> "$WG_CONF" <<EOF_CONF

# ------------------------------------------------------------
# Peer: ${PEER_NAME}
# Role: ${ROLE}
# ------------------------------------------------------------
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${PEER_IP}/32
EOF_CONF

chmod 600 "$WG_CONF"

echo "OK"

echo
echo "===== 7. GENERAR PERFIL CLIENTE ====="

{
    echo "[Interface]"
    echo "PrivateKey = ${CLIENT_PRIVATE_KEY}"
    echo "Address = ${PEER_IP}/32"
    echo "MTU = ${WG_MTU}"

    if [[ "$DNS_ACCESS" == "yes" ]]; then
        echo "DNS = ${DNS_SERVER}"
    fi

    echo
    echo "[Peer]"
    echo "PublicKey = ${SERVER_PUBLIC_KEY}"
    echo "Endpoint = ${ENDPOINT}"

    if [[ -n "$ALLOWED_IPS" ]]; then
        echo "AllowedIPs = ${ALLOWED_IPS}"
    else
        echo "AllowedIPs = 10.8.0.1/32"
    fi

    echo "PersistentKeepalive = 25"

} > "$PEER_CONF"

chmod 600 "$PEER_CONF"

install \
    -m 600 \
    -o "$PROJECT_USER" \
    -g "$PROJECT_GROUP" \
    "$PEER_CONF" \
    "$EXPORT_CONF"

echo "OK"

echo
echo "===== 8. CREAR METADATA ====="

cat > "$META_FILE" <<EOF_META
NAME=${PEER_NAME}
VPN_IP=${PEER_IP}
ROLE=${ROLE}
ENABLED=yes
EOF_META

chown "$PROJECT_USER:$PROJECT_GROUP" "$META_FILE"
chmod 644 "$META_FILE"

echo "OK"

echo
echo "===== 9. ACTUALIZAR INVENTARIO ====="

CREATED_AT="$(date -Is)"

printf '%s\t%s\t%s\t%s\t%s\n' \
    "$PEER_NAME" \
    "$PEER_IP" \
    "$CLIENT_PUBLIC_KEY" \
    "$CREATED_AT" \
    "active" \
    >> "$INVENTORY"

chown "$PROJECT_USER:$PROJECT_GROUP" "$INVENTORY"
chmod 600 "$INVENTORY"

echo "OK"

echo
echo "===== 10. REGENERAR FIREWALL ====="

"${PROJECT}/scripts/firewall_apply.sh"

echo
echo "===== 11. VALIDACION ====="

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
echo "Role:"
echo "  $ROLE"
echo
echo "DNS:"
if [[ "$DNS_ACCESS" == "yes" ]]; then
    echo "  $DNS_SERVER"
else
    echo "  none"
fi
echo
echo "AllowedIPs:"
echo "  ${ALLOWED_IPS:-10.8.0.1/32}"
echo
echo "Perfil:"
echo "  $EXPORT_CONF"
echo
echo "Metadata:"
echo "  $META_FILE"
echo
echo "QR:"
echo "  sudo ${PROJECT}/scripts/peer_qr.sh $PEER_NAME"
echo
echo "IMPORTANTE:"
echo "  El .conf contiene la clave privada."
echo "  No subirlo a Git."
echo "======================================================"
