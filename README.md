# WireGuardVPN — Ecuavisa UIO

VPN Broadcast segura para acceso remoto controlado a infraestructura
Ecuavisa UIO.

**Estado:** Producción  
**Release base:** `v1.0.0`  
**Servidor:** `videosrv`  
**VPN:** `10.8.0.0/24`  
**Endpoint:** `ebc.vnc.homes:51820`

---

## Arquitectura

```text
                 Clientes remotos
        Android / iOS / Windows / Linux
                         |
                         |
                 UDP/51820 WireGuard
                         |
                         v
                  +-------------+
                  |  videosrv   |
                  |   wg0       |
                  | 10.8.0.1/24 |
                  +------+------+
                         |
                  RBAC / Firewall
                         |
          +--------------+---------------+
          |              |               |
          v              v               v
   192.168.2.0/24  192.168.6.0/24 192.168.28.0/24
       LAN_UIO       BROADCAST_6       CORP_28
```

Dashboard:

```text
Cliente
   |
 HTTPS
443 / 9444
   |
   v
 Nginx
   |
   v
127.0.0.1:8095
   |
 FastAPI
   |
wireguardvpn-dashboard
   |
 sudo mínimo
   |
/usr/local/sbin/wireguardvpn-admin
```

---

## Acceso al dashboard

Acceso directo actual:

    https://192.168.2.168:9444

Acceso definitivo preparado:

    https://vpn.uio.ecuavisa.com

El nombre DNS institucional todavía puede estar pendiente.

Cuando exista:

    vpn.uio.ecuavisa.com A 192.168.2.168

no será necesario modificar Nginx ni el certificado.

---

## WireGuard

Interfaz:

    wg0

Servidor:

    10.8.0.1/24

Puerto:

    UDP/51820

Endpoint:

    ebc.vnc.homes:51820

MTU:

    1360

---

## Redes

| Red | CIDR | Interfaz/Ruta |
|---|---|---|
| VPN | `10.8.0.0/24` | `wg0` |
| LAN_UIO | `192.168.2.0/24` | `eno1` |
| BROADCAST_6 | `192.168.6.0/24` | `enp7s0` |
| CORP_28 | `192.168.28.0/24` | vía `192.168.2.3` |
| DNS interno | `192.168.2.10` | LAN |

---

## Roles

| Rol | Acceso |
|---|---|
| `none` | sin acceso a recursos |
| `server-only` | videosrv + DNS |
| `reportero` | DNS + MediaMTX/WebRTC + portal Fonos |
| `fonos` | reportero + SIP/RTP Asterisk |
| `tecnico` | VPN + redes 2/6/28 |

Definiciones:

    config/roles/

---

## Gestión de peers

El dashboard permite:

- crear peers;
- cambiar roles;
- generar QR;
- descargar `.conf`;
- regenerar perfiles;
- revocar peers;
- ver online/offline;
- handshake;
- endpoint;
- RX/TX;
- histórico.

Los nombres de peer son **únicos e inmutables**.

Ejemplo:

    android-vnc-01    revoked
    android-vnc-02    active

Un nombre revocado no se reutiliza.

---

## Dashboard

Backend:

    dashboard/app.py

Listener:

    127.0.0.1:8095

Servicio:

    wireguardvpn-dashboard.service

Usuario:

    wireguardvpn-dashboard

Privilege broker:

    /usr/local/sbin/wireguardvpn-admin

Nginx es el único frontend de red.

---

## Seguridad

La solución utiliza:

- WireGuard;
- RBAC;
- ACL específica para `wg0`;
- Nginx HTTPS;
- certificado firmado por CA institucional;
- HTTP Basic Auth;
- allowlist LAN/VPN;
- security headers;
- rate limiting;
- usuario systemd dedicado;
- sudo mínimo;
- broker root-owned;
- auditoría administrativa;
- filesystem permissions;
- backup root-only.

### Información que nunca debe publicarse

No compartir ni subir a Git:

    /etc/wireguard/server_private.key
    /etc/wireguard/peers/*.private.key
    data/peers/*.conf
    /etc/nginx/ssl/wireguardvpn/*.key
    /etc/nginx/auth/wireguardvpn.htpasswd
    backups/secure/*.tar.gz

Tampoco compartir la salida completa de:

    wg show wg0 dump

---

## Estado

```bash
cd /srv/WireGuardVPN
./tools/status.sh
```

---

## Snapshot para soporte o continuidad

```bash
./scripts/project_context_snapshot.sh
```

Genera:

    context_snapshot.txt

Para continuar el proyecto en otro chat compartir:

- `PROJECT_CONTEXT.md`;
- `context_snapshot.txt`;
- `README.md`.

---

## Backup

```bash
sudo ./scripts/backup.sh
```

Los backups se almacenan en:

    backups/secure/

y contienen secretos.

Deben conservarse protegidos y fuera de Git.

---

## Operación rápida

### Ver peers

```bash
./tools/peers.sh
```

### Estado de accesos

```bash
./tools/access_status.sh
```

### Roles

```bash
./tools/roles.sh
```

### Estado general

```bash
./tools/status.sh
```

### Auditoría

```bash
journalctl -t wireguardvpn-admin
```

### Estado WireGuard

```bash
sudo wg show wg0
```

---

## Servicios

```text
wg-quick@wg0.service
wireguardvpn-firewall.service
wireguardvpn-dashboard.service
nginx.service
```

---

## Estructura del proyecto

```text
/srv/WireGuardVPN
├── branding/
├── config/
│   ├── nginx/
│   ├── peers/
│   ├── privileged/
│   ├── roles/
│   ├── server/
│   ├── systemd/
│   ├── templates/
│   └── tls/
├── dashboard/
├── data/
│   └── peers/
├── docs/
├── scripts/
├── tools/
├── README.md
└── PROJECT_CONTEXT.md
```

---

## Documentación

- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md)
- [`docs/00_Indice.md`](docs/00_Indice.md)
- [`docs/01_Arquitectura_y_Operacion.md`](docs/01_Arquitectura_y_Operacion.md)
- [`docs/02_Disaster_Recovery.md`](docs/02_Disaster_Recovery.md)
- [`docs/07_Dashboard_HTTPS.md`](docs/07_Dashboard_HTTPS.md)
- [`branding/BRANDING_GUIDE.md`](branding/BRANDING_GUIDE.md)

---

## Release

Release inicial de producción:

    v1.0.0

Commit:

    9e1b6ce

El tag publicado `v1.0.0` es inmutable.

Los cambios posteriores de documentación pueden existir sobre `main`
sin modificar el tag de producción.

---

## Licencia / uso

Proyecto interno de Ecuavisa UIO.

Derechos de autor © 2025-2026 Ecuavisa UIO.

---
