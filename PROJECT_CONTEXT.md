# PROJECT CONTEXT
## WireGuardVPN - Ecuavisa UIO

### Objetivo

Implementar una VPN WireGuard centralizada en `videosrv` para permitir
acceso remoto seguro a la infraestructura broadcast de Ecuavisa Quito.

### Host

Hostname:

    videosrv

Sistema:

    Ubuntu 22.04.5 LTS

Kernel:

    5.15.0-194-generic

### Interfaces

LAN principal:

    eno1
    192.168.2.168/24

Gateway:

    192.168.2.3

Red secundaria:

    enp7s0
    192.168.6.31/24

### WireGuard

Red VPN:

    10.8.0.0/24

Servidor:

    10.8.0.1/24

Puerto:

    51820/UDP

MTU inicial:

    1360

### Estado inicial validado

WireGuard kernel module:

    disponible

wireguard-tools:

    no instalado

wg0:

    no configurado

IPv4 forwarding:

    desactivado

51820/UDP:

    libre

UFW:

    no instalado

nftables:

    no instalado

iptables FORWARD:

    sin reglas específicas

iptables NAT:

    sin reglas específicas

### Servicios relevantes actualmente activos

MediaMTX:

    activo

Puertos observados:

    8554/TCP
    8787/TCP
    8889/TCP
    8189/TCP+UDP
    8890/UDP

Nginx:

    9443/TCP

Servicios relacionados:

    mediamtx.service
    api_mediamtx.service
    fonos-server.service
    fonosip-portal.service

Asterisk:

    actualmente inactive

### Política de implementación

WireGuard se ejecutará directamente sobre el kernel del host.

El proyecto `/srv/WireGuardVPN` será autocontenido para:

- scripts
- documentación
- configuración declarativa
- gestión de peers
- diagnóstico
- backups
- snapshots

Las claves privadas permanecerán fuera de Git.

### Roadmap

Fase 0
Inicialización y baseline.

Fase 1
Instalación WireGuard + forwarding.

Fase 2
Configuración wg0 + firewall/routing.

Fase 3
Gestión estructurada de peers.

Fase 4
Primer cliente Android y pruebas 4G/5G.

Fase 5
Integración MediaMTX / Fonos IP.

Fase 6
Integración Asterisk / Linphone iOS.

Fase 7
Administración de peers desde FonosIP.

Fase 8
Hardening y retirada de exposición pública.

Fase 9
Backup, restore, monitoreo y documentación final.

## Estado validado - Fase 3

WireGuard operativo:

    wg0 = 10.8.0.1/24
    UDP = 51820
    MTU = 1360

Primer cliente Android validado mediante red movil.

Se verifico:

- handshake WireGuard
- trafico bidireccional
- acceso a servicios locales de videosrv
- acceso VPN -> LAN 192.168.2.0/24
- forwarding wg0 -> eno1
- MASQUERADE
- retorno LAN -> VPN
- acceso HTTP a equipos internos
- ICMP bidireccional

Arquitectura validada:

    Android
        |
        | WireGuard
        v
    wg0 / 10.8.0.1
        |
        | forwarding + NAT
        v
    eno1 / 192.168.2.168
        |
        v
    LAN 192.168.2.0/24

Los perfiles cliente permanecen excluidos de Git.

Siguiente etapa:

    Fase 4 - DNS interno y acceso a multiples redes corporativas
