# 04 - Gestion de Peers

## Principio

Cada dispositivo WireGuard posee:

- identidad unica
- IP VPN unica
- clave privada unica
- clave publica unica
- perfil independiente

Nunca se reutilizan perfiles entre dispositivos.

## Direccionamiento

Servidor:

    10.8.0.1

Clientes:

    10.8.0.2 - 10.8.0.254

Cada cliente utiliza:

    /32

Ejemplo:

    10.8.0.2/32

## Crear peer

    sudo ./scripts/peer_add.sh \
      android-test-01 \
      vpn.ecuavisa.com:51820

## Mostrar QR

    sudo ./scripts/peer_qr.sh android-test-01

## Inventario

    ./tools/peers.sh

Archivo:

    data/peers/inventory.tsv

El inventario NO contiene claves privadas.

## Revocar peer

    sudo ./scripts/peer_remove.sh android-test-01

Esto:

- elimina el peer del kernel
- elimina el peer de wg0.conf
- destruye su clave privada local
- elimina su perfil exportado
- marca el peer como revoked

## Seguridad

Los perfiles cliente contienen una clave privada.

Nunca deben:

- subirse a Git
- enviarse por correo sin proteccion
- copiarse a PROJECT_CONTEXT.md
- copiarse a context_snapshot.txt

El QR debe mostrarse únicamente durante el aprovisionamiento.
