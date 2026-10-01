#!/usr/bin/env bash
set -u

PROJECT="/srv/WireGuardVPN"

ok() {
    printf 'OK    %s\n' "$*"
}

warn() {
    printf 'WARN  %s\n' "$*"
}

fail() {
    printf 'FAIL  %s\n' "$*"
}

service_check() {
    local service="$1"

    if systemctl is-active --quiet "$service"; then
        ok "$service active"
    else
        fail "$service inactive"
    fi
}

echo "======================================================"
echo " WireGuardVPN - STATUS"
echo "======================================================"

echo
echo "===== SERVICES ====="

service_check wg-quick@wg0
service_check wireguardvpn-firewall.service
service_check wireguardvpn-dashboard.service
service_check nginx

echo
echo "===== FORWARDING ====="

if [[ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" == "1" ]]; then
    ok "net.ipv4.ip_forward=1"
else
    fail "net.ipv4.ip_forward disabled"
fi

echo
echo "===== WG ====="

if sudo -n wg show wg0 listen-port >/dev/null 2>&1; then
    port="$(sudo -n wg show wg0 listen-port)"

    if [[ "$port" == "51820" ]]; then
        ok "wg0 UDP/$port"
    else
        warn "wg0 listen-port=$port"
    fi
else
    warn "wg status requires sudo"
fi

echo
echo "===== DASHBOARD ====="

if curl -fsS \
    http://127.0.0.1:8095/health \
    >/dev/null 2>&1
then
    ok "FastAPI health"
else
    fail "FastAPI health"
fi

if curl -fsS \
    http://127.0.0.1:8095/api/peers \
    >/dev/null 2>&1
then
    ok "Peers API"
else
    fail "Peers API"
fi

echo
echo "===== LISTENERS ====="

if ss -ltn 2>/dev/null |
   grep -q '127.0.0.1:8095'
then
    ok "8095 localhost only"
else
    fail "8095 listener unexpected"
fi

if ss -ltn 2>/dev/null |
   grep -q ':9444 '
then
    ok "HTTPS 9444"
else
    warn "9444 not listening"
fi

if ss -ltn 2>/dev/null |
   grep -q ':443 '
then
    ok "HTTPS 443"
else
    warn "443 not listening"
fi

echo
echo "===== INVENTORY ====="

if [[ -r "${PROJECT}/data/peers/inventory.tsv" ]]; then
    active="$(
        awk -F '\t' '$5=="active"{n++} END{print n+0}' \
        "${PROJECT}/data/peers/inventory.tsv"
    )"

    revoked="$(
        awk -F '\t' '$5=="revoked"{n++} END{print n+0}' \
        "${PROJECT}/data/peers/inventory.tsv"
    )"

    ok "active=$active revoked=$revoked"
else
    fail "inventory not readable"
fi

echo
echo "===== NGINX ====="

if sudo -n nginx -t >/dev/null 2>&1; then
    ok "nginx configuration"
else
    warn "nginx -t requires sudo or has warnings/errors"
fi

echo
echo "===== GIT ====="

cd "$PROJECT" || exit 1

if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
    ok "working tree clean"
else
    warn "working tree has changes"
fi

echo
echo "======================================================"
