# 05 - Android

## Primer peer validado

Peer:

    android-test-01

VPN:

    10.8.0.2/32

Servidor:

    10.8.0.1/24

Transporte:

    WireGuard UDP/51820

MTU:

    1360

## Prueba externa

La validacion se realizo desde Android utilizando red movil
fuera de la LAN Wi-Fi de Ecuavisa.

WireGuard registro:

    latest handshake
    trafico bidireccional

## Acceso LAN

Desde Android conectado a WireGuard se pudo acceder a:

    https://192.168.2.168:8889/retorno

Esto valida:

- tunnel WireGuard
- routing VPN -> LAN
- forwarding Linux
- NAT VPN -> LAN
- acceso a MediaMTX desde un peer remoto

## Arquitectura confirmada

Los servicios internos pueden continuar utilizando sus direcciones
LAN existentes.

No es necesario migrar todos los servicios a 10.8.0.1.

WireGuard proporciona al cliente remoto acceso controlado a:

    192.168.2.0/24

mediante:

    AllowedIPs = 10.8.0.0/24, 192.168.2.0/24

## Seguridad

Cada dispositivo debe utilizar:

- clave privada independiente
- IP /32 independiente
- peer independiente
- capacidad de revocacion individual

Nunca se reutilizara el perfil de android-test-01 en otro dispositivo.
