#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"

WG_IF="wg0"

PEERS_DIR="${PROJECT}/config/peers"
ROLES_DIR="${PROJECT}/config/roles"
SERVICES_FILE="${PROJECT}/config/services.conf"
NETWORKS_FILE="${PROJECT}/config/networks.conf"

echo "======================================================"
echo " WireGuardVPN - FIREWALL GENERATOR"
echo " Role-based access control"
echo "======================================================"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

if ! ip link show "$WG_IF" >/dev/null 2>&1; then
    echo "ERROR: $WG_IF no existe"
    exit 1
fi

if [[ ! -d "$PEERS_DIR" ]]; then
    echo "ERROR: no existe $PEERS_DIR"
    exit 1
fi

echo
echo "===== 1. CREAR / LIMPIAR CADENAS ====="

iptables -N WG-INPUT 2>/dev/null || true
iptables -N WG-FORWARD 2>/dev/null || true
iptables -t nat -N WG-NAT 2>/dev/null || true

iptables -F WG-INPUT
iptables -F WG-FORWARD
iptables -t nat -F WG-NAT

echo "OK"

echo
echo "===== 2. ENGANCHAR wg0 ====="

iptables -C INPUT \
    -i "$WG_IF" \
    -j WG-INPUT 2>/dev/null ||
iptables -I INPUT 1 \
    -i "$WG_IF" \
    -j WG-INPUT

iptables -C FORWARD \
    -i "$WG_IF" \
    -j WG-FORWARD 2>/dev/null ||
iptables -I FORWARD 1 \
    -i "$WG_IF" \
    -j WG-FORWARD

iptables -t nat -C POSTROUTING \
    -s 10.8.0.0/24 \
    -j WG-NAT 2>/dev/null ||
iptables -t nat -I POSTROUTING 1 \
    -s 10.8.0.0/24 \
    -j WG-NAT

echo "OK"

echo
echo "===== 3. ESTABLISHED / RELATED ====="

iptables -A WG-INPUT \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

iptables -A WG-FORWARD \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

echo "OK"

get_service() {
    local name="$1"

    awk -v service="$name" '
        NF >= 4 &&
        $1 !~ /^#/ &&
        $1 == service {
            print $2, $3, $4
        }
    ' "$SERVICES_FILE"
}

get_network() {
    local name="$1"

    awk -v network="$name" '
        NF >= 4 &&
        $1 !~ /^#/ &&
        $1 == network {
            print $2, $3, $4
        }
    ' "$NETWORKS_FILE"
}

apply_service() {
    local peer_ip="$1"
    local service_name="$2"

    local line
    line="$(get_service "$service_name")"

    if [[ -z "$line" ]]; then
        echo "ERROR: servicio desconocido: $service_name"
        exit 1
    fi

    read -r destination protocol ports <<<"$line"

    # Determinar si el destino pertenece al propio videosrv.
    if ip -4 -o addr show |
       awk '{print $4}' |
       cut -d/ -f1 |
       grep -qx "$destination"; then

        echo "  SERVICE $service_name -> LOCAL $destination $protocol/$ports"

        iptables -A WG-INPUT \
            -s "${peer_ip}/32" \
            -d "${destination}/32" \
            -p "$protocol" \
            --dport "$ports" \
            -j ACCEPT

    else

        echo "  SERVICE $service_name -> FORWARD $destination $protocol/$ports"

        iptables -A WG-FORWARD \
            -s "${peer_ip}/32" \
            -d "${destination}/32" \
            -p "$protocol" \
            --dport "$ports" \
            -j ACCEPT

    fi
}

apply_network() {
    local peer_ip="$1"
    local network_name="$2"

    local line
    line="$(get_network "$network_name")"

    if [[ -z "$line" ]]; then
        echo "ERROR: red desconocida: $network_name"
        exit 1
    fi

    local cidr iface nat
    read -r cidr iface nat <<<"$line"

    if ! ip link show "$iface" >/dev/null 2>&1; then
        echo "ERROR: interfaz inexistente para $network_name: $iface"
        exit 1
    fi

    echo "  NETWORK $network_name -> $cidr via $iface NAT=$nat"

    iptables -A WG-FORWARD \
        -s "${peer_ip}/32" \
        -d "$cidr" \
        -j ACCEPT

    if [[ "$nat" == "yes" ]]; then

        if ! iptables -t nat -C WG-NAT \
            -s 10.8.0.0/24 \
            -d "$cidr" \
            -o "$iface" \
            -j MASQUERADE 2>/dev/null; then

            iptables -t nat -A WG-NAT \
                -s 10.8.0.0/24 \
                -d "$cidr" \
                -o "$iface" \
                -j MASQUERADE
        fi
    fi
}

echo
echo "===== 4. GENERAR POLITICA POR PEER ====="

shopt -s nullglob

for peer_file in "$PEERS_DIR"/*.meta; do

    unset NAME VPN_IP ROLE ENABLED
    unset SERVER_ACCESS DNS_ACCESS SERVICES NETWORKS

    # shellcheck disable=SC1090
    source "$peer_file"

    NAME="${NAME:-}"
    VPN_IP="${VPN_IP:-}"
    ROLE="${ROLE:-none}"
    ENABLED="${ENABLED:-no}"

    echo
    echo "Peer:"
    echo "  name=$NAME"
    echo "  ip=$VPN_IP"
    echo "  role=$ROLE"
    echo "  enabled=$ENABLED"

    if [[ "$ENABLED" != "yes" ]]; then
        echo "  SKIP: disabled"
        continue
    fi

    if [[ -z "$VPN_IP" ]]; then
        echo "ERROR: peer sin VPN_IP: $peer_file"
        exit 1
    fi

    ROLE_FILE="${ROLES_DIR}/${ROLE}.conf"

    if [[ ! -f "$ROLE_FILE" ]]; then
        echo "ERROR: rol inexistente: $ROLE"
        exit 1
    fi

    unset SERVER_ACCESS DNS_ACCESS SERVICES NETWORKS

    # shellcheck disable=SC1090
    source "$ROLE_FILE"

    SERVER_ACCESS="${SERVER_ACCESS:-no}"
    DNS_ACCESS="${DNS_ACCESS:-no}"
    SERVICES="${SERVICES:-}"
    NETWORKS="${NETWORKS:-}"

    echo "  server_access=$SERVER_ACCESS"
    echo "  dns_access=$DNS_ACCESS"

    if [[ "$SERVER_ACCESS" == "yes" ]]; then
        echo "  ALLOW local videosrv"

        iptables -A WG-INPUT \
            -s "${VPN_IP}/32" \
            -j ACCEPT
    fi

    if [[ "$DNS_ACCESS" == "yes" ]]; then
        echo "  ALLOW DNS 192.168.2.10"

        iptables -A WG-FORWARD \
            -s "${VPN_IP}/32" \
            -d 192.168.2.10/32 \
            -p udp \
            --dport 53 \
            -j ACCEPT

        iptables -A WG-FORWARD \
            -s "${VPN_IP}/32" \
            -d 192.168.2.10/32 \
            -p tcp \
            --dport 53 \
            -j ACCEPT
    fi

    for service in $SERVICES; do
        apply_service "$VPN_IP" "$service"
    done

    for network in $NETWORKS; do
        apply_network "$VPN_IP" "$network"
    done

    # Todo lo no autorizado del peer queda bloqueado.
    iptables -A WG-INPUT \
        -s "${VPN_IP}/32" \
        -j DROP

    iptables -A WG-FORWARD \
        -s "${VPN_IP}/32" \
        -j DROP

done

echo
echo "===== 5. DEFAULT DENY WG ====="

iptables -A WG-INPUT \
    -j DROP

iptables -A WG-FORWARD \
    -j DROP

echo
echo "===== 6. RESULTADO ====="

echo
echo "[WG-INPUT]"
iptables -L WG-INPUT -n -v --line-numbers

echo
echo "[WG-FORWARD]"
iptables -L WG-FORWARD -n -v --line-numbers

echo
echo "[WG-NAT]"
iptables -t nat -L WG-NAT -n -v --line-numbers

echo
echo "======================================================"
echo " FIREWALL GENERADO"
echo "======================================================"
