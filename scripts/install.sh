#!/usr/bin/env bash
set -euo pipefail

echo "======================================================"
echo " WireGuardVPN - FASE 1"
echo " Instalacion base + IPv4 forwarding"
echo "======================================================"
echo

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo:"
    echo "  sudo $0"
    exit 1
fi

echo "===== 1. VALIDAR HOST ====="
HOSTNAME_ACTUAL="$(hostname)"
echo "host=$HOSTNAME_ACTUAL"

if [[ "$HOSTNAME_ACTUAL" != "videosrv" ]]; then
    echo "ERROR: este instalador esta preparado para videosrv"
    exit 1
fi

echo
echo "===== 2. VALIDAR KERNEL WIREGUARD ====="
modprobe wireguard
lsmod | grep '^wireguard' || {
    echo "ERROR: modulo WireGuard no disponible"
    exit 1
}

echo "OK: modulo WireGuard disponible"

echo
echo "===== 3. INSTALAR PAQUETES ====="
export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
    wireguard \
    wireguard-tools \
    qrencode \
    iptables

echo
echo "===== 4. VERSIONES ====="
wg --version
qrencode --version | head -n 1
iptables --version

echo
echo "===== 5. CONFIGURAR IP FORWARDING ====="

SYSCTL_FILE="/etc/sysctl.d/99-wireguard-vpn.conf"

cat > "$SYSCTL_FILE" <<'SYSCTL'
# WireGuardVPN - Ecuavisa UIO
# Required for routing VPN clients toward internal networks.

net.ipv4.ip_forward = 1
SYSCTL

chmod 644 "$SYSCTL_FILE"

sysctl --system >/tmp/wireguardvpn-sysctl.log

CURRENT_FORWARD="$(sysctl -n net.ipv4.ip_forward)"

if [[ "$CURRENT_FORWARD" != "1" ]]; then
    echo "ERROR: net.ipv4.ip_forward no quedo habilitado"
    cat /tmp/wireguardvpn-sysctl.log
    exit 1
fi

echo "OK: net.ipv4.ip_forward = 1"

echo
echo "===== 6. CREAR /etc/wireguard ====="

install -d \
    -m 700 \
    -o root \
    -g root \
    /etc/wireguard

echo
echo "===== 7. VALIDAR PUERTO 51820 ====="

if ss -lun | grep -qE ':[[:space:]]*51820[[:space:]]'; then
    echo "ADVERTENCIA: 51820/UDP aparece ocupado"
    ss -lunp | grep ':51820' || true
else
    echo "OK: 51820/UDP libre"
fi

echo
echo "===== 8. VALIDAR INTERFAZ PRINCIPAL ====="

if ip link show eno1 >/dev/null 2>&1; then
    echo "OK: eno1 existe"
else
    echo "ERROR: eno1 no existe"
    exit 1
fi

IP_ENO1="$(
    ip -4 -o addr show dev eno1 |
    awk '{print $4}' |
    head -n1
)"

echo "eno1=$IP_ENO1"

if [[ "$IP_ENO1" != "192.168.2.168/24" ]]; then
    echo "ERROR: IP inesperada en eno1"
    echo "Esperada: 192.168.2.168/24"
    echo "Actual:   $IP_ENO1"
    exit 1
fi

echo
echo "===== 9. VALIDAR RUTA DEFAULT ====="

DEFAULT_ROUTE="$(ip route show default | head -n1)"
echo "$DEFAULT_ROUTE"

if ! grep -q 'via 192.168.2.3 dev eno1' <<<"$DEFAULT_ROUTE"; then
    echo "ADVERTENCIA: la ruta default no coincide exactamente con el baseline"
fi

echo
echo "===== 10. ESTADO FINAL ====="

echo
echo "[PACKAGES]"
dpkg -l |
grep -E '^ii[[:space:]]+(wireguard|wireguard-tools|qrencode|iptables)[[:space:]]'

echo
echo "[FORWARDING]"
sysctl net.ipv4.ip_forward

echo
echo "[WG]"
wg show || true

echo
echo "[WG DIR]"
ls -ld /etc/wireguard

echo
echo "[PORT]"
ss -lunp | grep ':51820' || echo "51820/UDP libre"

echo
echo "======================================================"
echo " FASE 1 COMPLETADA"
echo "======================================================"
