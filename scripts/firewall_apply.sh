#!/usr/bin/env bash
set -euo pipefail

WG_IF="wg0"

echo "======================================================"
echo " WireGuardVPN - FIREWALL"
echo " Default deny exclusivo para wg0"
echo "======================================================"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

if ! ip link show "$WG_IF" >/dev/null 2>&1; then
    echo "ERROR: $WG_IF no existe"
    exit 1
fi

echo
echo "===== 1. CREAR CADENAS ====="

iptables -N WG-INPUT 2>/dev/null || true
iptables -N WG-FORWARD 2>/dev/null || true

iptables -F WG-INPUT
iptables -F WG-FORWARD

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

echo "OK"

echo
echo "===== 3. TRAFICO DE RETORNO ====="

iptables -A WG-INPUT \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

iptables -A WG-FORWARD \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

echo "OK"

echo
echo "===== 4. PEER android-vnc-01 ====="

# ------------------------------------------------------------
# 10.8.0.2 - server-only
# ------------------------------------------------------------

# Acceso a cualquier servicio LOCAL de videosrv.
#
# El destino puede ser 10.8.0.1, 192.168.2.168 o 192.168.6.31.
#
iptables -A WG-INPUT \
    -s 10.8.0.2/32 \
    -j ACCEPT

# DNS corporativo.
iptables -A WG-FORWARD \
    -s 10.8.0.2/32 \
    -d 192.168.2.10/32 \
    -p udp \
    --dport 53 \
    -j ACCEPT

iptables -A WG-FORWARD \
    -s 10.8.0.2/32 \
    -d 192.168.2.10/32 \
    -p tcp \
    --dport 53 \
    -j ACCEPT

# Todo otro forwarding de este peer queda bloqueado.
iptables -A WG-FORWARD \
    -s 10.8.0.2/32 \
    -j DROP

echo "OK"

echo
echo "===== 5. DEFAULT DENY WG ====="

# Cualquier peer WireGuard no declarado:
#
# - no accede al propio servidor
# - no puede utilizar videosrv como router
#
iptables -A WG-INPUT \
    -j DROP

iptables -A WG-FORWARD \
    -j DROP

echo "OK"

echo
echo "===== 6. VALIDACION ====="

echo
echo "[INPUT]"
iptables -L WG-INPUT -n -v --line-numbers

echo
echo "[FORWARD]"
iptables -L WG-FORWARD -n -v --line-numbers

echo
echo "======================================================"
echo " FIREWALL WG APLICADO"
echo "======================================================"
