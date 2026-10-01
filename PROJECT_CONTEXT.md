# PROJECT_CONTEXT — WireGuardVPN Ecuavisa UIO

Última actualización: 2026-10-01  
Estado: PRODUCCIÓN  
Release base: `v1.0.0`  
Release commit: `9e1b6ce`  
Branch: `main`

> Este documento describe la arquitectura estable y las decisiones de
> producción de WireGuardVPN Ecuavisa UIO.
>
> El estado dinámico de peers, interfaces y servicios debe obtenerse con:
>
>     ./scripts/project_context_snapshot.sh
>     ./tools/status.sh

---

# 1. Objetivo

WireGuardVPN proporciona una VPN segura para Ecuavisa UIO destinada a
equipos Broadcast y técnicos remotos.

Permite conectar, entre otros:

- Android;
- iPhone;
- Windows/Linux;
- teléfonos IP;
- clientes SIP;
- MediaMTX/WebRTC;
- aplicaciones internas;
- estaciones técnicas.

El sistema aplica control de acceso por roles para que cada peer acceda
solamente a los recursos autorizados.

---

# 2. Servidor principal

Host:

    videosrv

Sistema operativo:

    Ubuntu Server 22.04.5 LTS

Kernel de referencia durante v1.0.0:

    5.15.0-194-generic

Proyecto:

    /srv/WireGuardVPN

Usuario técnico:

    tecnico_uio

Repositorio:

    github.com/vNcAltamirano/WireGuardVPN

Branch:

    main

Release de producción:

    v1.0.0

---

# 3. Red del servidor

## LAN principal

Interfaz:

    eno1

Dirección:

    192.168.2.168/24

Gateway:

    192.168.2.3

Red:

    192.168.2.0/24

Nombre lógico:

    LAN_UIO

## Red Broadcast

Interfaz:

    enp7s0

Dirección:

    192.168.6.31/24

Red:

    192.168.6.0/24

Nombre lógico:

    BROADCAST_6

## Red corporativa

Red:

    192.168.28.0/24

Acceso mediante:

    192.168.2.3

Nombre lógico:

    CORP_28

## DNS interno

Servidor:

    192.168.2.10

---

# 4. WireGuard

Interfaz:

    wg0

Servidor VPN:

    10.8.0.1/24

Pool de clientes:

    10.8.0.2 - 10.8.0.254

Cada peer utiliza:

    /32

Puerto:

    UDP/51820

MTU:

    1360

Endpoint público:

    ebc.vnc.homes:51820

Forwarding IPv4:

    net.ipv4.ip_forward=1

Servicio:

    wg-quick@wg0.service

El servicio está habilitado para iniciar automáticamente.

---

# 5. Archivos WireGuard runtime

Configuración:

    /etc/wireguard/wg0.conf

Clave privada servidor:

    /etc/wireguard/server_private.key

Clave pública servidor:

    /etc/wireguard/server_public.key

Secrets de peers:

    /etc/wireguard/peers/

IMPORTANTE:

- nunca subir estos archivos a Git;
- nunca publicar claves privadas;
- no compartir la salida completa de:

      wg show wg0 dump

La primera línea de `wg show wg0 dump` contiene material sensible del
servidor.

Utilizar para diagnóstico:

    sudo wg show wg0
    sudo wg show wg0 peers
    sudo wg show wg0 latest-handshakes

---

# 6. Rotación de clave del servidor

El 2026-10-01 se realizó una rotación de la clave WireGuard del servidor
después de una exposición accidental durante diagnóstico.

La nueva clave quedó aplicada en:

    /etc/wireguard/server_private.key
    /etc/wireguard/server_public.key
    /etc/wireguard/wg0.conf
    wg0 live

Los perfiles activos fueron regenerados para utilizar la nueva PublicKey
del servidor.

Material temporal con la clave antigua fue eliminado.

Cuando un cliente todavía tenga un perfil anterior a la rotación deberá
volver a importar su perfil actualizado.

---

# 7. Gestión de peers

Inventario:

    /srv/WireGuardVPN/data/peers/inventory.tsv

Metadata:

    /srv/WireGuardVPN/config/peers/<peer>.meta

Perfiles cliente:

    /srv/WireGuardVPN/data/peers/<peer>.conf

Los `.conf` contienen claves privadas de clientes.

Permisos operativos:

    /srv/WireGuardVPN/data
        root:wireguardvpn-ops 0750

    /srv/WireGuardVPN/data/peers
        root:wireguardvpn-ops 0750

    inventory.tsv
        root:wireguardvpn-ops 0640

    *.conf
        root:wireguardvpn-ops 0640

---

# 8. Política de nombres de peers

El nombre de un peer es un identificador único e inmutable.

Un peer revocado permanece en el histórico.

Ejemplo:

    android-vnc-01     revoked
    android-vnc-02     active

NO reutilizar:

    android-vnc-01

aunque esté revocado.

Esto mantiene trazabilidad de:

- IP utilizada;
- clave pública histórica;
- fecha de creación;
- estado;
- dispositivo/reemplazo.

---

# 9. Scripts de peers

Principales:

    scripts/peer_add.sh
    scripts/peer_remove.sh
    scripts/peer_qr.sh
    scripts/peer_set_role.sh
    scripts/peer_refresh_config.sh
    scripts/firewall_apply.sh

Herramientas:

    tools/peers.sh
    tools/access_status.sh
    tools/roles.sh
    tools/status.sh

---

# 10. Roles

Los roles se almacenan en:

    config/roles/

## none

Sin acceso a recursos.

Perfil mínimo:

    10.8.0.1/32

## server-only

Acceso a:

- videosrv;
- DNS interno.

AllowedIPs típicos:

    10.8.0.0/24
    192.168.2.168/32
    192.168.2.10/32

## reportero

Incluye:

- DNS interno;
- MediaMTX WebRTC;
- ICE UDP/TCP;
- portal Fonos.

## fonos

Incluye `reportero` más:

- Asterisk SIP UDP;
- Asterisk SIP TCP;
- RTP.

## tecnico

Acceso administrativo/técnico:

    10.8.0.0/24
    192.168.2.0/24
    192.168.6.0/24
    192.168.28.0/24

---

# 11. Redes y servicios declarativos

Redes:

    config/networks.conf

Servicios:

    config/services.conf

Redes conocidas:

    LAN_UIO
    BROADCAST_6
    CORP_28

Servicios definidos incluyen:

- DNS interno;
- MediaMTX WebRTC;
- MediaMTX ICE;
- RTSP;
- HLS;
- Fonos Portal;
- Asterisk SIP;
- Asterisk RTP.

---

# 12. Firewall

No se implementó un firewall host global para videosrv.

WireGuard utiliza cadenas específicas:

    WG-INPUT
    WG-FORWARD
    WG-NAT

La política se aplica únicamente al tráfico relacionado con `wg0`.

Servicio persistente:

    wireguardvpn-firewall.service

Script:

    scripts/firewall_apply.sh

El firewall se deriva de:

- peer;
- rol;
- networks.conf;
- services.conf.

---

# 13. Dashboard

Backend:

    FastAPI

Ruta:

    /srv/WireGuardVPN/dashboard

Virtualenv:

    /srv/WireGuardVPN/dashboard/.venv

Listener:

    127.0.0.1:8095

IMPORTANTE:

El backend nunca debe escuchar directamente en:

    0.0.0.0:8095

Servicio:

    wireguardvpn-dashboard.service

Usuario runtime:

    wireguardvpn-dashboard

Grupo runtime:

    wireguardvpn-dashboard

Grupo suplementario:

    wireguardvpn-ops

---

# 14. Funciones del dashboard

El dashboard permite:

- ver peers activos;
- ver peers revocados;
- online/offline;
- endpoint;
- último handshake;
- RX/TX;
- VPN IP;
- rol;
- recursos;
- crear peer;
- cambiar rol;
- refrescar perfil;
- generar QR;
- descargar `.conf`;
- revocar peer.

Los históricos muestran fechas usando:

    America/Guayaquil

Formato visual:

    DD/MM/YYYY HH:MM:SS

El timestamp ISO original se conserva internamente.

---

# 15. Modelo privilegiado del dashboard

FastAPI NO ejecuta directamente scripts editables del proyecto como root.

Usuario:

    wireguardvpn-dashboard

Sudo permitido:

    /usr/local/sbin/wireguardvpn-status
    /usr/local/sbin/wireguardvpn-admin *

Privilege broker:

    /usr/local/sbin/wireguardvpn-admin

Propietario:

    root:root

Permisos:

    0755

Copia versionada:

    config/privileged/wireguardvpn-admin

Sudoers:

    /etc/sudoers.d/wireguardvpn-dashboard

Copia versionada:

    config/privileged/wireguardvpn-dashboard.sudoers

El usuario `wireguardvpn-dashboard` no debe poder modificar:

- scripts administrativos;
- roles;
- services.conf;
- networks.conf;
- privilege broker.

---

# 16. systemd hardening

El dashboard utiliza aislamiento systemd compatible con el broker sudo.

Entre otros:

    ProtectSystem=full
    ProtectHome=true
    PrivateTmp=true
    ProtectControlGroups=true
    UMask=0077

IMPORTANTE:

    NoNewPrivileges=false

es intencional.

No cambiarlo automáticamente a `true` porque impediría el salto sudo
controlado hacia `/usr/local/sbin/wireguardvpn-admin`.

La seguridad real se basa en:

- usuario dedicado;
- sudoers mínimo;
- broker root-owned;
- permisos de filesystem;
- Nginx;
- TLS;
- allowlist de redes.

---

# 17. Auditoría administrativa

Las operaciones privilegiadas generan eventos mediante:

    logger -t wireguardvpn-admin

Consulta:

    journalctl -t wireguardvpn-admin

Ejemplo conceptual:

    caller=wireguardvpn-dashboard
    action=refresh
    peer=pc-vnc-01

---

# 18. Dashboard HTTPS / Nginx

Backend:

    http://127.0.0.1:8095

Acceso directo actual:

    https://192.168.2.168:9444

Acceso definitivo preparado:

    https://vpn.uio.ecuavisa.com

Puerto normal definitivo:

    TCP/443

Puerto administrativo/directo:

    TCP/9444

Nginx exige:

- HTTPS;
- HTTP Basic Authentication;
- allowlist de redes;
- security headers;
- rate limiting;
- control de origen para operaciones POST.

Redes permitidas:

    10.8.0.0/24
    192.168.2.0/24
    192.168.6.0/24
    192.168.28.0/24

Archivo auth:

    /etc/nginx/auth/wireguardvpn.htpasswd

No mostrar ni versionar su contenido.

---

# 19. TLS

Certificado servidor:

    /etc/nginx/ssl/wireguardvpn/vpn.uio.ecuavisa.com.crt

Clave privada TLS:

    /etc/nginx/ssl/wireguardvpn/vpn.uio.ecuavisa.com.key

Root CA instalada:

    /etc/nginx/ssl/wireguardvpn/ecuavisa_root.crt

SAN del certificado:

    DNS:vpn.uio.ecuavisa.com
    DNS:videosrv.ecuavisa.com
    IP:192.168.2.168

La clave privada de la Root CA institucional NO debe almacenarse en
videosrv.

---

# 20. DNS pendiente

La infraestructura está preparada para:

    vpn.uio.ecuavisa.com

Cuando se implemente DNS institucional crear:

    vpn.uio.ecuavisa.com  A  192.168.2.168

Mientras tanto utilizar:

    https://192.168.2.168:9444

No se requiere modificar el certificado ni Nginx cuando se cree el DNS.

---

# 21. Branding

Branding reutilizable:

    branding/

Incluye:

    branding/assets/
    branding/css/
    branding/templates/
    branding/source/
    branding/BRANDING_GUIDE.md

Tema visual:

- dark UI;
- branding Ecuavisa UIO;
- responsive desktop/tablet/mobile.

---

# 22. Backup

Script:

    scripts/backup.sh

Ejecutar:

    sudo ./scripts/backup.sh

Destino:

    backups/secure/

Los backups contienen:

- configuración WireGuard;
- claves;
- TLS;
- htpasswd;
- systemd;
- sudoers;
- privilege broker;
- config del proyecto;
- data de peers;
- commit Git.

IMPORTANTE:

Los backups contienen secretos y deben permanecer:

    root:root 0600

Nunca subir `backups/secure/` a Git.

---

# 23. Disaster Recovery

Documento:

    docs/02_Disaster_Recovery.md

Orden de recuperación:

1. networking del host;
2. WireGuard;
3. firewall WireGuard;
4. dashboard;
5. Nginx;
6. cliente real.

Servicios esenciales:

    wg-quick@wg0
    wireguardvpn-firewall.service
    wireguardvpn-dashboard.service
    nginx

---

# 24. Herramienta de estado

Ejecutar:

    ./tools/status.sh

Comprueba:

- servicios;
- forwarding;
- WireGuard;
- dashboard health;
- API peers;
- listeners;
- inventario;
- Nginx;
- Git.

---

# 25. Snapshot de contexto

Generar:

    ./scripts/project_context_snapshot.sh

Salida:

    context_snapshot.txt

El snapshot NO contiene:

- claves privadas;
- contenido de `.conf` de clientes.

El archivo está excluido de Git.

---

# 26. Diagnóstico básico

Estado completo:

    ./tools/status.sh

Servicios:

    systemctl status wg-quick@wg0
    systemctl status wireguardvpn-firewall.service
    systemctl status wireguardvpn-dashboard.service
    systemctl status nginx

WireGuard seguro para compartir:

    sudo wg show wg0
    sudo wg show wg0 latest-handshakes

Dashboard:

    curl -fsS http://127.0.0.1:8095/health

API:

    curl -fsS http://127.0.0.1:8095/api/peers

Auditoría:

    journalctl -t wireguardvpn-admin

---

# 27. Git

Repositorio:

    vNcAltamirano/WireGuardVPN

Branch:

    main

Release inicial de producción:

    v1.0.0

Commit de release:

    9e1b6ce

IMPORTANTE:

`v1.0.0` es un tag publicado y debe considerarse inmutable.

Cambios documentales posteriores pueden dejar `main` por delante de
`v1.0.0`.

No mover ni recrear el tag publicado.

---

# 28. Estado de fases

    Fase 1      Base WireGuard                     COMPLETA
    Fase 2      wg0 / persistencia                 COMPLETA
    Fase 3      Gestión de peers                   COMPLETA
    Fase 4      RBAC / Multi-LAN                   COMPLETA
    Fase 5.1    Dashboard read-only                COMPLETA
    Fase 5.2    Administración                     COMPLETA
    Fase 5.3    UI / QR / descarga                 COMPLETA
    Fase 5.4    Nginx / HTTPS / auth               COMPLETA
    Fase 5.5    Hardening                          COMPLETA
    Fase 6      Docs / backup / release            COMPLETA

Estado:

    PRODUCCIÓN

---

# 29. Pendientes no bloqueantes

## DNS

Crear posteriormente:

    vpn.uio.ecuavisa.com -> 192.168.2.168

## Nginx externo al proyecto

`nginx -t` puede mostrar warnings de otros vhosts relacionados con:

    192.168.2.168:9094
    192.168.2.168:8891
    vnc.homes:9091

No corresponden a WireGuardVPN.

## Peers offline

Un peer activo puede aparecer offline simplemente porque el dispositivo
está apagado/desconectado.

Después de una rotación de la clave del servidor, los clientes que aún
tengan configuraciones antiguas deben volver a importar su perfil.

---

# 30. Archivos que compartir con ChatGPT para retomar el proyecto

En un nuevo chat compartir:

1. `PROJECT_CONTEXT.md`
2. `context_snapshot.txt`
3. `README.md`

Para una incidencia concreta añadir el archivo relevante, por ejemplo:

    config/nginx/wireguardvpn.conf
    config/systemd/wireguardvpn-dashboard.service
    config/networks.conf
    config/services.conf
    config/roles/<role>.conf
    scripts/firewall_apply.sh
    dashboard/app.py

NO compartir:

    /etc/wireguard/server_private.key
    /etc/wireguard/peers/*.private.key
    data/peers/*.conf
    vpn.uio.ecuavisa.com.key
    wireguardvpn.htpasswd
    backups/secure/*.tar.gz

---

# 31. Regla para futuras mejoras

Antes de modificar producción:

1. ejecutar `./tools/status.sh`;
2. generar `context_snapshot.txt`;
3. verificar `git status`;
4. crear branch feature/fix;
5. realizar cambios;
6. validar;
7. documentar;
8. merge/tag según corresponda.

No realizar cambios estructurales directamente sobre producción sin
mantener sincronizados:

- Git;
- documentación;
- configuración runtime;
- backup/recovery.

