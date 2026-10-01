#!/usr/bin/env bash
set -euo pipefail

PROJECT="/srv/WireGuardVPN"
BACKUP_ROOT="${PROJECT}/backups/secure"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: ejecutar con sudo" >&2
    exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="${BACKUP_ROOT}/.${STAMP}"
ARCHIVE="${BACKUP_ROOT}/wireguardvpn-${STAMP}.tar.gz"

install \
  -d \
  -o root \
  -g root \
  -m 0700 \
  "$BACKUP_ROOT"

install \
  -d \
  -o root \
  -g root \
  -m 0700 \
  "$WORK"

cleanup() {
    rm -rf "$WORK"
}

trap cleanup EXIT

mkdir -p \
  "$WORK/etc/wireguard" \
  "$WORK/etc/nginx" \
  "$WORK/etc/systemd/system" \
  "$WORK/etc/sudoers.d" \
  "$WORK/usr/local/sbin" \
  "$WORK/project"

cp -a \
  /etc/wireguard/. \
  "$WORK/etc/wireguard/"

cp -a \
  /etc/nginx/ssl/wireguardvpn \
  "$WORK/etc/nginx/" 2>/dev/null || true

cp -a \
  /etc/nginx/auth/wireguardvpn.htpasswd \
  "$WORK/etc/nginx/" 2>/dev/null || true

cp -a \
  /etc/nginx/sites-available/wireguardvpn.conf \
  "$WORK/etc/nginx/" 2>/dev/null || true

cp -a \
  /etc/systemd/system/wireguardvpn-firewall.service \
  "$WORK/etc/systemd/system/" 2>/dev/null || true

cp -a \
  /etc/systemd/system/wireguardvpn-dashboard.service \
  "$WORK/etc/systemd/system/" 2>/dev/null || true

cp -a \
  /etc/sudoers.d/wireguardvpn-dashboard \
  "$WORK/etc/sudoers.d/" 2>/dev/null || true

cp -a \
  /usr/local/sbin/wireguardvpn-admin \
  "$WORK/usr/local/sbin/" 2>/dev/null || true

cp -a \
  "$PROJECT/config" \
  "$WORK/project/"

cp -a \
  "$PROJECT/data" \
  "$WORK/project/"

git -C "$PROJECT" \
  rev-parse HEAD \
  > "$WORK/project/git_commit.txt"

date -Is \
  > "$WORK/project/backup_created.txt"

tar \
  -C "$WORK" \
  -czf "$ARCHIVE" \
  .

chown root:root "$ARCHIVE"
chmod 0600 "$ARCHIVE"

sha256sum "$ARCHIVE" \
  > "${ARCHIVE}.sha256"

chown root:root "${ARCHIVE}.sha256"
chmod 0600 "${ARCHIVE}.sha256"

echo "======================================================"
echo " WireGuardVPN BACKUP OK"
echo "======================================================"
echo
echo "Archive:"
echo "  $ARCHIVE"
echo
echo "SHA256:"
echo "  ${ARCHIVE}.sha256"
echo
echo "IMPORTANTE:"
echo "  Este backup contiene claves privadas."
echo "  Mantenerlo protegido y fuera de Git."
