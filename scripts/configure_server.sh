#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"

WG_IF="wg0"
WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_IF}.conf"

PRIVATE_KEY="${WG_DIR}/server_private.key"
PUBLIC_KEY="${WG_DIR}/server_public.key"

WG_ADDRESS="10.8.0.1/24"
WG_NETWORK="10.8.0.0/24"
WG_PORT="51820"
WG_MTU="1360"

LAN_IF="eno1"
LAN_ADDRESS="192.168.2.168/24"
LAN_NETWORK="192.168.2.0/24"
LAN_GATEWAY="192.168.2.3"

echo "======================================================"
echo " WireGuardVPN - FASE 2"
echo " Configuracion servidor wg0"
echo "======================================================"
echo

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo:"
    echo "  sudo $0"
    exit 1
fi

echo "===== 1. VALIDAR HOST ====="

if [[ "$(hostname)" != "videosrv" ]]; then
    echo "ERROR: este script esta preparado para videosrv"
    exit 1
fi

echo "OK: host=videosrv"

echo
echo "===== 2. VALIDAR DEPENDENCIAS ====="

for cmd in wg wg-quick ip iptables systemctl ss; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: falta comando: $cmd"
        exit 1
    fi
done

echo "OK: dependencias disponibles"

echo
echo "===== 3. VALIDAR FORWARDING ====="

FORWARD="$(sysctl -n net.ipv4.ip_forward)"

if [[ "$FORWARD" != "1" ]]; then
    echo "ERROR: net.ipv4.ip_forward=$FORWARD"
    echo "Ejecutar primero scripts/install.sh"
    exit 1
fi

echo "OK: net.ipv4.ip_forward=1"

echo
echo "===== 4. VALIDAR LAN ====="

if ! ip link show "$LAN_IF" >/dev/null 2>&1; then
    echo "ERROR: no existe interfaz $LAN_IF"
    exit 1
fi

CURRENT_LAN_IP="$(
    ip -4 -o addr show dev "$LAN_IF" |
    awk '{print $4}' |
    head -n1
)"

echo "$LAN_IF=$CURRENT_LAN_IP"

if [[ "$CURRENT_LAN_IP" != "$LAN_ADDRESS" ]]; then
    echo "ERROR: direccion inesperada en $LAN_IF"
    echo "Esperada: $LAN_ADDRESS"
    echo "Actual:   $CURRENT_LAN_IP"
    exit 1
fi

DEFAULT_ROUTE="$(ip route show default | head -n1)"

echo "$DEFAULT_ROUTE"

if ! grep -q "via ${LAN_GATEWAY} dev ${LAN_IF}" <<<"$DEFAULT_ROUTE"; then
    echo "ERROR: gateway principal inesperado"
    exit 1
fi

echo "OK: LAN validada"

echo
echo "===== 5. VALIDAR RED VPN ====="

if ip route show "$WG_NETWORK" | grep -q .; then

    if ip link show "$WG_IF" >/dev/null 2>&1; then
        echo "INFO: $WG_NETWORK ya pertenece a $WG_IF"
    else
        echo "ERROR: la red $WG_NETWORK ya existe en routing"
        ip route show "$WG_NETWORK"
        exit 1
    fi

else
    echo "OK: $WG_NETWORK disponible"
fi

echo
echo "===== 6. PREPARAR /etc/wireguard ====="

install \
    -d \
    -m 700 \
    -o root \
    -g root \
    "$WG_DIR"

echo "OK: $WG_DIR"

echo
echo "===== 7. CLAVES DEL SERVIDOR ====="

umask 077

if [[ ! -f "$PRIVATE_KEY" ]]; then

    wg genkey > "$PRIVATE_KEY"

    chmod 600 "$PRIVATE_KEY"

    echo "OK: clave privada creada"

else

    echo "INFO: clave privada existente - NO se regenera"

fi

wg pubkey < "$PRIVATE_KEY" > "$PUBLIC_KEY"

chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"

SERVER_PRIVATE_KEY="$(cat "$PRIVATE_KEY")"
SERVER_PUBLIC_KEY="$(cat "$PUBLIC_KEY")"

if [[ -z "$SERVER_PRIVATE_KEY" || -z "$SERVER_PUBLIC_KEY" ]]; then
    echo "ERROR: claves invalidas"
    exit 1
fi

echo "OK: public key generada"
echo "Server PublicKey:"
echo "$SERVER_PUBLIC_KEY"

echo
echo "===== 8. GENERAR wg0.conf ====="

TMP_CONF="$(mktemp)"

cat > "$TMP_CONF" <<EOF_CONF
# ============================================================
# WireGuardVPN - Ecuavisa UIO
# Managed by:
# /srv/WireGuardVPN/scripts/configure_server.sh
# ============================================================

[Interface]

Address = ${WG_ADDRESS}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
MTU = ${WG_MTU}
SaveConfig = false

# Firewall and NAT are managed by:
# /srv/WireGuardVPN/scripts/firewall_apply.sh
#
# Do not add PostUp/PostDown firewall rules here.

# Peers are managed separately.
EOF_CONF

install \
    -o root \
    -g root \
    -m 600 \
    "$TMP_CONF" \
    "$WG_CONF"

rm -f "$TMP_CONF"

echo "OK: $WG_CONF"

echo
echo "===== 9. VALIDAR CONFIGURACION ====="

wg-quick strip "$WG_IF" >/dev/null

echo "OK: sintaxis wg0 valida"

echo
echo "===== 10. ACTIVAR wg0 ====="

systemctl daemon-reload

if systemctl is-active --quiet "wg-quick@${WG_IF}.service"; then

    echo "INFO: reiniciando wg0 existente"

    systemctl restart "wg-quick@${WG_IF}.service"

else

    systemctl enable --now "wg-quick@${WG_IF}.service"

fi

echo
echo "===== 11. VALIDAR INTERFAZ ====="

if ! ip link show "$WG_IF" >/dev/null 2>&1; then
    echo "ERROR: $WG_IF no existe despues del arranque"
    systemctl status "wg-quick@${WG_IF}.service" --no-pager || true
    exit 1
fi

ip -br addr show "$WG_IF"

echo
echo "===== 12. VALIDAR WIREGUARD ====="

wg show "$WG_IF"

echo
echo "===== 13. VALIDAR PUERTO ====="

if ss -lunp | grep -q ":${WG_PORT} "; then
    ss -lunp | grep ":${WG_PORT} "
else
    echo "ERROR: ${WG_PORT}/UDP no esta escuchando"
    exit 1
fi

echo
echo "===== 14. VALIDAR ROUTING ====="

ip route show "$WG_NETWORK"

echo
ip route get 10.8.0.2

echo
echo "===== 15. VALIDAR FIREWALL ====="

echo
echo "[FORWARD VPN -> LAN]"
iptables -C FORWARD \
    -i "$WG_IF" \
    -o "$LAN_IF" \
    -s "$WG_NETWORK" \
    -d "$LAN_NETWORK" \
    -j ACCEPT

echo "OK"

echo
echo "[FORWARD LAN -> VPN]"
iptables -C FORWARD \
    -i "$LAN_IF" \
    -o "$WG_IF" \
    -s "$LAN_NETWORK" \
    -d "$WG_NETWORK" \
    -m conntrack \
    --ctstate RELATED,ESTABLISHED \
    -j ACCEPT

echo "OK"

echo
echo "[NAT VPN -> LAN]"
iptables -t nat -C POSTROUTING \
    -s "$WG_NETWORK" \
    -d "$LAN_NETWORK" \
    -o "$LAN_IF" \
    -j MASQUERADE

echo "OK"

echo
echo "===== 16. ESTADO SYSTEMD ====="

systemctl is-enabled "wg-quick@${WG_IF}.service"
systemctl is-active "wg-quick@${WG_IF}.service"

echo
echo "======================================================"
echo " FASE 2 COMPLETADA"
echo "======================================================"
echo
echo "WireGuard Server:"
echo "  Interface : $WG_IF"
echo "  Address   : $WG_ADDRESS"
echo "  Port      : $WG_PORT/UDP"
echo "  MTU       : $WG_MTU"
echo
echo "PublicKey:"
echo "  $SERVER_PUBLIC_KEY"
echo
echo "IMPORTANTE:"
echo "  Todavia NO existen peers."
echo "  No debe existir handshake."
echo "======================================================"
