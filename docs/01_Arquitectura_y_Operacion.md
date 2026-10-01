# WireGuardVPN — Ecuavisa UIO

## 1. Objetivo

WireGuardVPN proporciona acceso remoto seguro a recursos Broadcast de
Ecuavisa UIO mediante WireGuard y control de acceso por roles.

Servidor principal:

    videosrv

VPN:

    wg0
    10.8.0.1/24
    UDP/51820

Endpoint publico:

    ebc.vnc.homes:51820

## 2. Redes

LAN_UIO:

    192.168.2.0/24
    interfaz eno1
    videosrv 192.168.2.168

BROADCAST_6:

    192.168.6.0/24
    interfaz enp7s0
    videosrv 192.168.6.31

CORP_28:

    192.168.28.0/24
    via 192.168.2.3

DNS interno:

    192.168.2.10

VPN:

    10.8.0.0/24

## 3. Servicios

WireGuard:

    wg-quick@wg0
    UDP/51820

Dashboard:

    wireguardvpn-dashboard.service
    127.0.0.1:8095

Nginx:

    TCP/443
    TCP/9444

Acceso actual:

    https://192.168.2.168:9444

Acceso definitivo cuando exista DNS:

    https://vpn.uio.ecuavisa.com

## 4. Roles

none
    Sin acceso a recursos.

server-only
    Acceso a videosrv y DNS interno.

reportero
    DNS + MediaMTX WebRTC/ICE + portal Fonos.

fonos
    Reportero + SIP/RTP Asterisk.

tecnico
    Acceso a LAN_UIO, BROADCAST_6 y CORP_28.

## 5. Modelo de peer

El nombre de un peer es un identificador unico e inmutable.

Ejemplo:

    android-vnc-01    revoked
    android-vnc-02    active

Un nombre revocado NO se reutiliza.

Cada alta nueva genera:

- nueva clave privada cliente;
- nueva clave publica cliente;
- nueva asignacion VPN disponible;
- nuevo timestamp;
- nuevo perfil;
- nuevo QR.

## 6. Inventario

Inventario:

    /srv/WireGuardVPN/data/peers/inventory.tsv

Metadata:

    /srv/WireGuardVPN/config/peers/*.meta

Perfiles privados:

    /srv/WireGuardVPN/data/peers/*.conf

Los perfiles contienen claves privadas y NO deben subirse a Git.

## 7. Seguridad

Dashboard FastAPI:

    usuario wireguardvpn-dashboard

Privilegios sudo permitidos exclusivamente:

    /usr/local/sbin/wireguardvpn-status
    /usr/local/sbin/wireguardvpn-admin *

Privilege broker:

    /usr/local/sbin/wireguardvpn-admin
    root:root 0755

Copia versionada:

    config/privileged/wireguardvpn-admin

Sudoers versionado:

    config/privileged/wireguardvpn-dashboard.sudoers

Los scripts del proyecto no son modificables por el usuario del dashboard.

## 8. TLS

Certificado:

    /etc/nginx/ssl/wireguardvpn/vpn.uio.ecuavisa.com.crt

Clave TLS:

    /etc/nginx/ssl/wireguardvpn/vpn.uio.ecuavisa.com.key

Root CA:

    Ecuavisa Root CA

SAN:

    vpn.uio.ecuavisa.com
    videosrv.ecuavisa.com
    192.168.2.168

Nunca copiar la clave privada de la Root CA a videosrv.

## 9. WireGuard secrets

Claves servidor:

    /etc/wireguard/server_private.key
    /etc/wireguard/server_public.key

Configuracion:

    /etc/wireguard/wg0.conf

Secrets de peers:

    /etc/wireguard/peers/

Todos estos archivos deben tratarse como secretos.

## 10. Operacion normal

Crear peer:

    Dashboard -> Nuevo peer

Cambiar rol:

    Dashboard -> selector Rol

Obtener movil:

    QR

Obtener PC:

    Descargar .conf

Revocar:

    Dashboard -> Revocar

Regenerar perfil:

    Dashboard -> Regenerar

Un perfil regenerado debe volver a importarse en el cliente cuando
cambien claves del servidor, DNS o AllowedIPs.

## 11. Auditoria

Acciones administrativas:

    journalctl -t wireguardvpn-admin

Servicio dashboard:

    journalctl -u wireguardvpn-dashboard.service

WireGuard:

    sudo wg show wg0

No compartir:

    wg show wg0 dump

La salida dump contiene informacion sensible.

## 12. Dependencia DNS pendiente

Cuando DNS institucional este disponible crear:

    vpn.uio.ecuavisa.com A 192.168.2.168

No requiere cambios adicionales en Nginx ni en el certificado.

## 13. Advertencias Nginx externas

nginx -t actualmente reporta warnings de otros servicios sobre:

    192.168.2.168:9094
    192.168.2.168:8891
    vnc.homes:9091

No corresponden a WireGuardVPN.

La configuracion WireGuardVPN pasa:

    nginx configuration test is successful
