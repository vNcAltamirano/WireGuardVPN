#!/usr/bin/env bash

set -u

PROJECT="/srv/WireGuardVPN"
OUTPUT="${PROJECT}/context_snapshot.txt"

{
    echo "======================================================"
    echo " WireGuardVPN - CONTEXT SNAPSHOT"
    echo "======================================================"
    echo
    date -Is
    echo

    echo "===== HOST ====="
    hostnamectl
    echo

    echo "===== PROJECT GIT ====="
    cd "$PROJECT"

    git status --short --branch 2>/dev/null || true
    git log -5 --oneline 2>/dev/null || true
    echo

    echo "===== PROJECT TREE ====="
    find "$PROJECT" \
        -maxdepth 3 \
        -type f \
        ! -name '*.key' \
        ! -name '*.private' \
        ! -name '*.secret' \
        ! -name 'context_snapshot.txt' \
        | sort
    echo

    echo "===== NETWORK ====="
    ip -br addr
    echo
    ip route
    echo

    echo "===== FORWARDING ====="
    sysctl net.ipv4.ip_forward
    echo

    echo "===== WG ====="
    if command -v wg >/dev/null 2>&1; then
        sudo wg show
    else
        echo "wireguard-tools no instalado"
    fi
    echo

    echo "===== WG SERVICE ====="
    systemctl status wg-quick@wg0.service \
        --no-pager 2>/dev/null || true
    echo

    echo "===== IPTABLES FORWARD ====="
    sudo iptables -S FORWARD 2>/dev/null || true
    echo

    echo "===== IPTABLES NAT ====="
    sudo iptables -t nat -S 2>/dev/null || true
    echo

    echo "===== PORT 51820 ====="
    sudo ss -lunp | grep ':51820 ' || true
    echo

    echo "======================================================"
} > "$OUTPUT"

chmod 600 "$OUTPUT"

echo
echo "Snapshot generado:"
echo "$OUTPUT"
echo
ls -lh "$OUTPUT"
