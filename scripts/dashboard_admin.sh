#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"
SCRIPTS="${PROJECT}/scripts"
ROLES="${PROJECT}/config/roles"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

valid_peer() {
    [[ "$1" =~ ^[a-zA-Z0-9._-]{1,64}$ ]]
}

valid_role() {
    valid_peer "$1" &&
    [[ -f "${ROLES}/${1}.conf" ]]
}

valid_endpoint() {
    local endpoint="$1"

    [[ "$endpoint" =~ ^[A-Za-z0-9._:-]+$ ]] || return 1

    [[ "$endpoint" == *:* ]] || return 1

    local port="${endpoint##*:}"

    [[ "$port" =~ ^[0-9]+$ ]] || return 1

    (( port >= 1 && port <= 65535 ))
}

if [[ $EUID -ne 0 ]]; then
    die "debe ejecutarse como root"
fi

ACTION="${1:-}"

case "$ACTION" in

    add)
        [[ $# -eq 4 ]] ||
            die "uso: dashboard_admin.sh add PEER ENDPOINT ROLE"

        PEER="$2"
        ENDPOINT="$3"
        ROLE="$4"

        valid_peer "$PEER" ||
            die "peer invalido"

        valid_endpoint "$ENDPOINT" ||
            die "endpoint invalido"

        valid_role "$ROLE" ||
            die "rol invalido"

        exec "${SCRIPTS}/peer_add.sh" \
            "$PEER" \
            "$ENDPOINT" \
            "$ROLE"
        ;;

    remove)
        [[ $# -eq 2 ]] ||
            die "uso: dashboard_admin.sh remove PEER"

        PEER="$2"

        valid_peer "$PEER" ||
            die "peer invalido"

        exec "${SCRIPTS}/peer_remove.sh" \
            "$PEER"
        ;;

    set-role)
        [[ $# -eq 3 ]] ||
            die "uso: dashboard_admin.sh set-role PEER ROLE"

        PEER="$2"
        ROLE="$3"

        valid_peer "$PEER" ||
            die "peer invalido"

        valid_role "$ROLE" ||
            die "rol invalido"

        exec "${SCRIPTS}/peer_set_role.sh" \
            "$PEER" \
            "$ROLE"
        ;;

    refresh)
        [[ $# -eq 3 ]] ||
            die "uso: dashboard_admin.sh refresh PEER ENDPOINT"

        PEER="$2"
        ENDPOINT="$3"

        valid_peer "$PEER" ||
            die "peer invalido"

        valid_endpoint "$ENDPOINT" ||
            die "endpoint invalido"

        exec "${SCRIPTS}/peer_refresh_config.sh" \
            "$PEER" \
            "$ENDPOINT"
        ;;

    *)
        die "accion no permitida"
        ;;

esac
