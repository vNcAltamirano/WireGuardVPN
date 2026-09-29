# 02 - Instalacion Base

## Objetivo

Instalar las herramientas necesarias para WireGuard en `videosrv`
y habilitar IPv4 forwarding de forma persistente.

## Paquetes

- wireguard
- wireguard-tools
- qrencode
- iptables

## Kernel

WireGuard utiliza el modulo nativo disponible en el kernel Linux.

Validacion:

    sudo modprobe wireguard
    lsmod | grep wireguard

## IPv4 forwarding

Archivo gestionado por el proyecto:

    /etc/sysctl.d/99-wireguard-vpn.conf

Contenido:

    net.ipv4.ip_forward = 1

Este parametro permite que `videosrv` enrute trafico entre:

    wg0
    eno1

y, posteriormente, otras redes internas autorizadas.

## Directorio operativo

WireGuard utilizara:

    /etc/wireguard

Permisos:

    root:root
    0700

Las claves privadas y configuraciones operativas no se almacenan en Git.

## Ejecucion

    cd /srv/WireGuardVPN
    sudo ./scripts/install.sh

## Validacion esperada

    wg --version
    sysctl net.ipv4.ip_forward
    ls -ld /etc/wireguard

Resultado esperado:

    net.ipv4.ip_forward = 1

En esta fase aun NO existe:

    wg0
    wg0.conf
    claves del servidor
    peers
    reglas NAT WireGuard
