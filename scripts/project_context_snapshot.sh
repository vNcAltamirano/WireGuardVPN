#!/usr/bin/env bash
set -u

PROJECT="/srv/WireGuardVPN"
OUT="${PROJECT}/context_snapshot.txt"

cd "$PROJECT" || exit 1

{
    echo "WireGuardVPN - Ecuavisa UIO"
    echo "Snapshot: $(date -Is)"
    echo

    echo "===== HOST ====="
    hostnamectl 2>/dev/null |
        grep -E 'Static hostname|Operating System|Kernel' || true

    echo
    echo "===== GIT ====="
    echo "branch=$(git branch --show-current)"
    echo "commit=$(git rev-parse HEAD)"
    git status --short

    echo
    echo "===== NETWORK ====="
    ip -brief address show \
      eno1 enp7s0 wg0 2>/dev/null || true

    echo
    echo "===== ROUTES ====="
    ip route |
      grep -E \
      '^(default|10\.8\.0\.0/24|192\.168\.2\.0/24|192\.168\.6\.0/24|192\.168\.28\.0/24)' \
      || true

    echo
    echo "===== SERVICES ====="

    for service in \
      wg-quick@wg0 \
      wireguardvpn-firewall.service \
      wireguardvpn-dashboard.service \
      nginx
    do
        printf '%-40s %s\n' \
          "$service" \
          "$(systemctl is-active "$service" 2>/dev/null || true)"
    done

    echo
    echo "===== WG ====="
    echo "interface=wg0"
    echo "address=10.8.0.1/24"
    echo "listen_port=$(sudo -n wg show wg0 listen-port 2>/dev/null || echo unavailable)"

    echo
    echo "===== INVENTORY ====="

    if [[ -r data/peers/inventory.tsv ]]; then
        awk -F '\t' '
        {
            printf "%-24s %-14s %-10s %s\n",
                $1, $2, $5, $4
        }' data/peers/inventory.tsv
    fi

    echo
    echo "===== ROLES ====="
    find config/roles \
      -maxdepth 1 \
      -type f \
      -printf '%f\n' |
      sort

    echo
    echo "===== LISTENERS ====="
    ss -lntup 2>/dev/null |
      grep -E \
      ':(51820|443|9444|8095)[[:space:]]' \
      || true

    echo
    echo "===== IMPORTANT PATHS ====="
    echo "/etc/wireguard/wg0.conf"
    echo "/etc/wireguard/server_private.key"
    echo "/etc/wireguard/server_public.key"
    echo "/etc/wireguard/peers/"
    echo "/etc/nginx/sites-available/wireguardvpn.conf"
    echo "/etc/nginx/ssl/wireguardvpn/"
    echo "/etc/nginx/auth/wireguardvpn.htpasswd"
    echo "/usr/local/sbin/wireguardvpn-admin"
    echo "/etc/sudoers.d/wireguardvpn-dashboard"

    echo
    echo "===== NOTES ====="
    echo "Private keys are intentionally NOT included."
    echo "Peer .conf contents are intentionally NOT included."
} > "$OUT"

chmod 0600 "$OUT"

echo "OK: $OUT"
