#!/usr/bin/env bash
set -u

PROJECT="/srv/WireGuardVPN"
ERRORS=0
WARNINGS=0

cd "$PROJECT" || exit 1

ok() {
    printf 'OK    %s\n' "$*"
}

warn() {
    printf 'WARN  %s\n' "$*"
    WARNINGS=$((WARNINGS + 1))
}

fail() {
    printf 'FAIL  %s\n' "$*"
    ERRORS=$((ERRORS + 1))
}

echo "======================================================"
echo " WireGuardVPN - DOCUMENTATION AUDIT"
echo "======================================================"

echo
echo "===== REQUIRED DOCUMENTS ====="

for item in \
    README.md \
    PROJECT_CONTEXT.md \
    docs/00_Indice.md \
    docs/01_Arquitectura_y_Operacion.md \
    docs/02_Disaster_Recovery.md \
    docs/07_Dashboard_HTTPS.md \
    branding/BRANDING_GUIDE.md
do
    if [[ -s "$item" ]]; then
        ok "$item"
    else
        fail "missing/empty: $item"
    fi
done

echo
echo "===== RELEASE ====="

if git rev-parse -q --verify refs/tags/v1.0.0 >/dev/null; then
    release_commit="$(git rev-list -n1 v1.0.0)"
    ok "v1.0.0 -> ${release_commit:0:7}"
else
    fail "tag v1.0.0 missing"
fi

echo
echo "===== REQUIRED CURRENT VALUES ====="

checks=(
    'README.md|ebc.vnc.homes:51820'
    'README.md|127.0.0.1:8095'
    'README.md|192.168.2.168:9444'
    'PROJECT_CONTEXT.md|wireguardvpn-dashboard'
    'PROJECT_CONTEXT.md|wireguardvpn-admin'
    'PROJECT_CONTEXT.md|wireguardvpn-ops'
    'PROJECT_CONTEXT.md|/etc/nginx/auth/wireguardvpn.htpasswd'
    'PROJECT_CONTEXT.md|NoNewPrivileges=false'
)

for check in "${checks[@]}"; do
    file="${check%%|*}"
    value="${check#*|}"

    if grep -Fq "$value" "$file"; then
        ok "$file contains $value"
    else
        fail "$file missing $value"
    fi
done

echo
echo "===== STALE / INVALID REFERENCES ====="

bad_patterns=(
    '/etc/nginx/.htpasswd-wireguardvpn'
    'wireguardvpni.htpasswd'
    'IdentityFile ~/.ssh/gireguardvpn.key'
)

for pattern in "${bad_patterns[@]}"; do
    output="$(
        grep -RInF \
          --exclude='docs_audit.sh' \
          --exclude-dir='.git' \
          --exclude-dir='backups' \
          "$pattern" \
          README.md \
          PROJECT_CONTEXT.md \
          docs \
          2>/dev/null || true
    )"

    if [[ -n "$output" ]]; then
        fail "stale reference: $pattern"
        printf '%s\n' "$output"
    else
        ok "no stale reference: $pattern"
    fi
done

echo
echo "===== LEGACY DASHBOARD PRIVILEGE PATH ====="

legacy="$(
    grep -RInF \
      '/srv/WireGuardVPN/scripts/dashboard_admin.sh' \
      README.md \
      PROJECT_CONTEXT.md \
      docs \
      2>/dev/null || true
)"

if [[ -n "$legacy" ]]; then
    warn "legacy dashboard_admin.sh referenced in docs"
    printf '%s\n' "$legacy"
else
    ok "no legacy privileged wrapper references"
fi

echo
echo "===== SECRETS TRACKED BY GIT ====="

tracked_secrets="$(
    git ls-files |
    grep -E \
      '(^|/)(server_private\.key|.*\.private\.key|.*\.key|wireguardvpn\.htpasswd)$|^data/peers/.*\.conf$|^backups/secure/' \
      || true
)"

if [[ -n "$tracked_secrets" ]]; then
    fail "potential secret files tracked"
    printf '%s\n' "$tracked_secrets"
else
    ok "no known runtime secrets tracked"
fi

echo
echo "===== GENERATED TLS TRACKED ====="

tls_tracked="$(
    git ls-files |
    grep -E '^config/tls/.*\.(key|crt|csr)$' \
    || true
)"

if [[ -n "$tls_tracked" ]]; then
    fail "generated TLS material tracked"
    printf '%s\n' "$tls_tracked"
else
    ok "generated TLS material excluded"
fi

echo
echo "===== PRIVILEGED RUNTIME COPIES ====="

if sudo cmp -s \
    config/privileged/wireguardvpn-admin \
    /usr/local/sbin/wireguardvpn-admin
then
    ok "privilege broker matches Git"
else
    fail "privilege broker differs from Git"
fi

if sudo cmp -s \
    config/privileged/wireguardvpn-dashboard.sudoers \
    /etc/sudoers.d/wireguardvpn-dashboard
then
    ok "sudoers matches Git"
else
    fail "sudoers differs from Git"
fi

echo
echo "===== NGINX REPO / RUNTIME ====="

if sudo cmp -s \
    config/nginx/wireguardvpn.conf \
    /etc/nginx/sites-available/wireguardvpn.conf
then
    ok "Nginx config matches runtime"
else
    warn "Nginx config differs from runtime"
fi

echo
echo "===== SYSTEMD REPO / RUNTIME ====="

if sudo cmp -s \
    config/systemd/wireguardvpn-dashboard.service \
    /etc/systemd/system/wireguardvpn-dashboard.service
then
    ok "dashboard service matches runtime"
else
    warn "dashboard service differs from runtime"
fi

if sudo cmp -s \
    config/systemd/wireguardvpn-firewall.service \
    /etc/systemd/system/wireguardvpn-firewall.service
then
    ok "firewall service matches runtime"
else
    warn "firewall service differs from runtime"
fi

echo
echo "===== LOCAL MARKDOWN LINKS ====="

python3 - <<'PY'
from pathlib import Path
import re

root = Path("/srv/WireGuardVPN")

files = [
    root / "README.md",
    root / "PROJECT_CONTEXT.md",
    *sorted((root / "docs").glob("*.md")),
]

errors = []

pattern = re.compile(r"\[[^\]]+\]\(([^)]+)\)")

for file in files:
    if not file.exists():
        continue

    text = file.read_text(errors="replace")

    for target in pattern.findall(text):
        if (
            target.startswith("http://")
            or target.startswith("https://")
            or target.startswith("#")
            or target.startswith("mailto:")
        ):
            continue

        target = target.split("#", 1)[0]

        if not target:
            continue

        resolved = (file.parent / target).resolve()

        if not resolved.exists():
            errors.append(
                f"{file.relative_to(root)} -> {target}"
            )

if errors:
    print("FAIL")
    for item in errors:
        print("  " + item)
    raise SystemExit(1)

print("OK")
PY

if [[ $? -eq 0 ]]; then
    ok "local Markdown links"
else
    fail "broken local Markdown links"
fi

echo
echo "===== CURRENT DOCUMENT FILES ====="

find docs \
  -maxdepth 1 \
  -type f \
  -name '*.md' \
  -printf '%f\n' |
sort

echo
echo "===== SUMMARY ====="

echo "errors=$ERRORS"
echo "warnings=$WARNINGS"

if (( ERRORS > 0 )); then
    echo
    echo "RESULT: FAIL"
    exit 1
fi

echo
echo "RESULT: OK"

exit 0
