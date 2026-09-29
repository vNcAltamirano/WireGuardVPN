# WireGuardVPN - Ecuavisa UIO

Infraestructura VPN WireGuard para servicios broadcast de Ecuavisa Quito.

## Servidor

- Host: videosrv
- OS: Ubuntu Server 22.04 LTS
- LAN Broadcast: 192.168.2.0/24
- IP LAN servidor: 192.168.2.168
- Interfaz LAN principal: eno1
- Red secundaria: 192.168.6.0/24
- Interfaz secundaria: enp7s0

## VPN

- Interfaz: wg0
- Red: 10.8.0.0/24
- Servidor: 10.8.0.1/24
- Puerto: 51820/UDP
- Clientes: 10.8.0.2 - 10.8.0.254
- MTU inicial: 1360

## Objetivo

Proporcionar acceso remoto seguro a servicios broadcast internos:

- Fonos IP
- MediaMTX
- WebRTC
- Asterisk / SIP / RTP
- Portales web internos
- Herramientas de administración

sin exponer directamente estos servicios a Internet.

## Seguridad

Las claves privadas y perfiles reales de clientes NO se almacenan
en el repositorio Git.

La configuración WireGuard operativa reside en:

    /etc/wireguard/

Este proyecto contiene automatización, documentación, plantillas,
diagnóstico y herramientas de administración.

## Estado

Fase 0 - Inicialización del proyecto.
