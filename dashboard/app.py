from __future__ import annotations

import csv
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
from typing import Any

from fastapi import FastAPI, Form, HTTPException
from fastapi.responses import HTMLResponse, PlainTextResponse, RedirectResponse, Response, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.requests import Request


PROJECT = Path("/srv/WireGuardVPN")

INVENTORY = PROJECT / "data/peers/inventory.tsv"
PEERS_DIR = PROJECT / "config/peers"
ROLES_DIR = PROJECT / "config/roles"
EXPORT_DIR = PROJECT / "data/peers"

TEMPLATES_DIR = PROJECT / "dashboard/templates"

app = FastAPI(
    title="WireGuardVPN Ecuavisa",
    version="0.2.0",
)

templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

app.mount(
    "/static",
    StaticFiles(directory=str(PROJECT / "dashboard/static")),
    name="static",
)


def run_command(args: list[str]) -> str:
    result = subprocess.run(
        args,
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout


def run_admin(action: str, *args: str) -> str:
    wrapper = Path("/usr/local/sbin/wireguardvpn-admin")

    cmd = [
        "sudo",
        "-n",
        str(wrapper),
        action,
        *args,
    ]

    result = subprocess.run(
        cmd,
        text=True,
        capture_output=True,
    )

    if result.returncode != 0:
        raise HTTPException(
            status_code=500,
            detail=(
                result.stderr
                or result.stdout
                or "admin command failed"
            ),
        )

    return result.stdout


def parse_meta(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}

    if not path.exists():
        return data

    for raw in path.read_text().splitlines():
        raw = raw.strip()

        if not raw or raw.startswith("#"):
            continue

        if "=" not in raw:
            continue

        key, value = raw.split("=", 1)
        data[key.strip()] = value.strip().strip('"')

    return data



UI_TIMEZONE = ZoneInfo("America/Guayaquil")


def format_ui_datetime(value: str) -> str:
    """Convierte timestamp ISO a hora local Ecuavisa UIO."""
    if not value:
        return ""

    try:
        normalized = value

        if normalized.endswith("Z"):
            normalized = normalized[:-1] + "+00:00"

        dt = datetime.fromisoformat(normalized)

        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=UI_TIMEZONE)

        local_dt = dt.astimezone(UI_TIMEZONE)

        return local_dt.strftime("%d/%m/%Y %H:%M:%S")

    except (ValueError, TypeError):
        return value


def inventory_rows() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []

    if not INVENTORY.exists():
        return rows

    with INVENTORY.open() as fh:
        reader = csv.reader(fh, delimiter="\t")

        for row in reader:
            if len(row) < 5:
                continue

            rows.append(
                {
                    "name": row[0],
                    "vpn_ip": row[1],
                    "public_key": row[2],
                    "created_at_iso": row[3],
            "created_at": format_ui_datetime(row[3]),
                    "status": row[4],
                }
            )

    return rows


def wg_dump() -> dict[str, dict[str, Any]]:
    output = run_command(
        ["sudo", "-n", "/usr/bin/wg", "show", "wg0", "dump"]
    )
    lines = output.strip().splitlines()

    peers: dict[str, dict[str, Any]] = {}

    if len(lines) <= 1:
        return peers

    for line in lines[1:]:
        cols = line.split("\t")

        if len(cols) < 8:
            continue

        public_key = cols[0]

        try:
            latest_handshake = int(cols[4])
        except ValueError:
            latest_handshake = 0

        try:
            rx = int(cols[5])
        except ValueError:
            rx = 0

        try:
            tx = int(cols[6])
        except ValueError:
            tx = 0

        peers[public_key] = {
            "endpoint": cols[2],
            "allowed_ips": cols[3],
            "latest_handshake": latest_handshake,
            "rx": rx,
            "tx": tx,
        }

    return peers


def is_online(timestamp: int) -> bool:
    if timestamp <= 0:
        return False

    now = int(datetime.now(timezone.utc).timestamp())

    return (now - timestamp) <= 180


def format_bytes(value: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]

    size = float(value)

    for unit in units:
        if size < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(size)} {unit}"

            return f"{size:.1f} {unit}"

        size /= 1024

    return f"{value} B"


def relative_time(timestamp: int) -> str:
    if timestamp <= 0:
        return "nunca"

    now = int(datetime.now(timezone.utc).timestamp())
    delta = max(0, now - timestamp)

    if delta < 60:
        return f"hace {delta} s"

    if delta < 3600:
        return f"hace {delta // 60} min"

    if delta < 86400:
        return f"hace {delta // 3600} h"

    return f"hace {delta // 86400} d"


def client_defaults() -> dict[str, str]:
    path = PROJECT / "config/server/client.conf"

    values: dict[str, str] = {}

    if not path.exists():
        raise RuntimeError(
            f"client defaults not found: {path}"
        )

    for raw in path.read_text().splitlines():
        line = raw.strip()

        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)

        values[key.strip()] = value.strip().strip('"')

    endpoint = values.get("WG_ENDPOINT", "")

    if not endpoint:
        raise RuntimeError(
            "WG_ENDPOINT is not configured"
        )

    return values


def parse_role(role_name: str) -> dict[str, Any]:
    path = ROLES_DIR / f"{role_name}.conf"

    if not path.exists():
        return {
            "name": role_name,
            "server_access": "no",
            "dns_access": "no",
            "services": [],
            "networks": [],
            "allowed_ips": "",
        }

    values: dict[str, str] = {}

    current_key: str | None = None
    current_lines: list[str] = []

    for raw in path.read_text().splitlines():
        line = raw.strip()

        if not line or line.startswith("#"):
            continue

        if current_key is not None:
            if line == '"':
                values[current_key] = " ".join(current_lines)
                current_key = None
                current_lines = []
            else:
                current_lines.append(line)

            continue

        if "=" not in line:
            continue

        key, value = line.split("=", 1)

        key = key.strip()
        value = value.strip()

        if value == '"':
            current_key = key
            current_lines = []
            continue

        values[key] = value.strip('"')

    return {
        "name": role_name,
        "server_access": values.get("SERVER_ACCESS", "no"),
        "dns_access": values.get("DNS_ACCESS", "no"),
        "services": values.get("SERVICES", "").split(),
        "networks": values.get("NETWORKS", "").split(),
        "allowed_ips": values.get("ALLOWED_IPS", ""),
    }


def peer_view() -> list[dict[str, Any]]:
    live = wg_dump()
    result: list[dict[str, Any]] = []

    for item in inventory_rows():
        meta = parse_meta(PEERS_DIR / f"{item['name']}.meta")
        wg = live.get(item["public_key"], {})

        timestamp = int(wg.get("latest_handshake", 0) or 0)

        result.append(
            {
                **item,
                "role": meta.get("ROLE", "none"),
                "enabled": meta.get("ENABLED", "no"),
                "online": is_online(timestamp),
                "endpoint": wg.get("endpoint", ""),
                "latest_handshake": timestamp,
                "rx": wg.get("rx", 0),
                "tx": wg.get("tx", 0),
                "rx_human": format_bytes(int(wg.get("rx", 0) or 0)),
                "tx_human": format_bytes(int(wg.get("tx", 0) or 0)),
                "handshake_human": relative_time(timestamp),
                "role_detail": parse_role(meta.get("ROLE", "none")),
            }
        )

    return result


def roles() -> list[str]:
    return sorted(p.stem for p in ROLES_DIR.glob("*.conf"))


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/peers")
def api_peers() -> list[dict[str, Any]]:
    return peer_view()


@app.get("/api/roles")
def api_roles() -> list[str]:
    return roles()


@app.get("/api/peers/{name}")
def api_peer(name: str) -> dict[str, Any]:
    for peer in peer_view():
        if peer["name"] == name:
            return peer

    raise HTTPException(
        status_code=404,
        detail="peer not found",
    )


@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="dashboard.html",
        context={
            "peers": peer_view(),
            "roles": roles(),
            "app_name": "WireGuardVPN",
            "app_description": "Concentrador VPN Broadcast",
            "hostname": "videosrv",
            "wg_endpoint": client_defaults()["WG_ENDPOINT"],
        },
    )


@app.post("/admin/peers-auto")
def create_peer_auto(
    name: str = Form(...),
    role: str = Form(...),
):
    endpoint = client_defaults()["WG_ENDPOINT"]

    run_admin(
        "add",
        name,
        endpoint,
        role,
    )

    return RedirectResponse(
        url="/",
        status_code=303,
    )


@app.post("/admin/peers/{name}/refresh-auto")
def refresh_peer_auto(name: str):
    endpoint = client_defaults()["WG_ENDPOINT"]

    run_admin(
        "refresh",
        name,
        endpoint,
    )

    return RedirectResponse(
        url="/",
        status_code=303,
    )


@app.post("/admin/peers")
def create_peer(
    name: str = Form(...),
    endpoint: str = Form(...),
    role: str = Form(...),
):
    if role not in roles():
        raise HTTPException(status_code=400, detail="invalid role")

    run_admin(
        "add",
        name,
        endpoint,
        role,
    )

    return RedirectResponse("/", status_code=303)


@app.post("/admin/peers/{name}/role")
def change_role(
    name: str,
    role: str = Form(...),
):
    if role not in roles():
        raise HTTPException(status_code=400, detail="invalid role")

    run_admin(
        "set-role",
        name,
        role,
    )

    return RedirectResponse("/", status_code=303)


@app.post("/admin/peers/{name}/revoke")
def revoke_peer(name: str):
    run_admin(
        "remove",
        name,
    )

    return RedirectResponse("/", status_code=303)


@app.post("/admin/peers/{name}/refresh")
def refresh_peer(
    name: str,
    endpoint: str = Form(...),
):
    run_admin(
        "refresh",
        name,
        endpoint,
    )

    return RedirectResponse("/", status_code=303)


@app.get("/admin/peers/{name}/profile")
def peer_profile(name: str):
    if not name or name != Path(name).name:
        raise HTTPException(
            status_code=400,
            detail="invalid peer name",
        )

    conf = EXPORT_DIR / f"{name}.conf"

    if not conf.exists():
        raise HTTPException(
            status_code=404,
            detail="profile not found",
        )

    return FileResponse(
        path=str(conf),
        media_type="text/plain",
        filename=f"{name}.conf",
        headers={
            "Cache-Control": "no-store, no-cache, must-revalidate",
            "Pragma": "no-cache",
        },
    )


@app.get("/admin/peers/{name}/qr")
def peer_qr(name: str):
    conf = EXPORT_DIR / f"{name}.conf"

    if not conf.exists():
        raise HTTPException(
            status_code=404,
            detail="profile not found",
        )

    result = subprocess.run(
        [
            "/usr/bin/qrencode",
            "-t",
            "PNG",
            "-s",
            "6",
            "-m",
            "2",
            "-o",
            "-",
            "-r",
            str(conf),
        ],
        capture_output=True,
    )

    if result.returncode != 0:
        raise HTTPException(
            status_code=500,
            detail="QR generation failed",
        )

    return Response(
        content=result.stdout,
        media_type="image/png",
        headers={
            "Cache-Control": "no-store",
        },
    )
