#!/usr/bin/env bash
set -euo pipefail

BACKUP="/srv/WireGuardVPN/backups/iptables-before-phase4.rules"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo"
    exit 1
fi

if [[ ! -f "$BACKUP" ]]; then
    echo "ERROR: no existe $BACKUP"
    exit 1
fi

iptables-restore < "$BACKUP"

echo "Firewall restaurado:"
echo "$BACKUP"
