# 03 - Configuracion del servidor WireGuard

## Interfaz

    wg0

## Direccionamiento

Servidor:

    10.8.0.1/24

Red VPN:

    10.8.0.0/24

Puerto:

    51820/UDP

MTU:

    1360

## LAN inicial autorizada

    192.168.2.0/24

Interfaz:

    eno1

IP videosrv:

    192.168.2.168

Gateway:

    192.168.2.3

## Criptografia

Archivos operativos:

    /etc/wireguard/server_private.key
    /etc/wireguard/server_public.key

La clave privada:

- pertenece a root
- tiene permisos 0600
- nunca se almacena en Git
- nunca debe copiarse a PROJECT_CONTEXT.md
- nunca debe copiarse a context_snapshot.txt

## Configuracion activa

    /etc/wireguard/wg0.conf

Permisos:

    0600

Servicio:

    wg-quick@wg0.service

## NAT

La primera fase utiliza MASQUERADE exclusivamente para:

    10.8.0.0/24 -> 192.168.2.0/24

Esto permite que los equipos de planta respondan a los clientes VPN
sin necesidad de agregar inicialmente una ruta 10.8.0.0/24 en el
gateway de la LAN.

No se realiza NAT hacia Internet.

No se realiza NAT hacia 192.168.6.0/24.

## Routing secundario

La interfaz:

    enp7s0
    192.168.6.31/24

queda fuera del alcance inicial de WireGuard.

Podra agregarse posteriormente de forma explicita si existe un
requerimiento real.

## Peers

En esta fase no existen peers.

La gestion de clientes comienza en la Fase 3.
