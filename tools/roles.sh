#!/usr/bin/env bash
set -u

PROJECT="/srv/WireGuardVPN"
ROLES_DIR="${PROJECT}/config/roles"

echo "======================================================"
echo " WireGuardVPN - ROLES"
echo "======================================================"

for file in "$ROLES_DIR"/*.conf; do

    [[ -e "$file" ]] || continue

    unset ROLE SERVER_ACCESS DNS_ACCESS SERVICES NETWORKS ALLOWED_IPS

    # shellcheck disable=SC1090
    source "$file"

    echo
    echo "ROLE: ${ROLE:-unknown}"
    echo "  server_access : ${SERVER_ACCESS:-no}"
    echo "  dns_access    : ${DNS_ACCESS:-no}"
    echo "  allowed_ips   : ${ALLOWED_IPS:-none}"

    if [[ -n "${SERVICES:-}" ]]; then
        echo "  services:"
        for service in $SERVICES; do
            echo "    - $service"
        done
    fi

    if [[ -n "${NETWORKS:-}" ]]; then
        echo "  networks:"
        for network in $NETWORKS; do
            echo "    - $network"
        done
    fi

done

echo
