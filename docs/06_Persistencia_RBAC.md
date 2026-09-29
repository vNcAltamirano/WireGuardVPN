# 06 - Persistencia WireGuard RBAC

## Objetivo

Separar completamente:

- WireGuard
- control de acceso
- NAT Multi-LAN

## WireGuard

Servicio:

    wg-quick@wg0.service

Responsabilidades:

- crear wg0
- asignar 10.8.0.1/24
- escuchar UDP/51820
- cargar peers
- MTU 1360

No gestiona firewall ni NAT.

## Firewall VPN

Servicio:

    wireguardvpn-firewall.service

Script:

    /srv/WireGuardVPN/scripts/firewall_apply.sh

Responsabilidades:

- WG-INPUT
- WG-FORWARD
- WG-NAT
- RBAC por peer
- servicios autorizados
- redes autorizadas
- NAT Multi-LAN

## Alcance

Las reglas de control se aplican solamente al trafico WireGuard.

No se modifica la politica global del servidor:

    INPUT ACCEPT
    FORWARD ACCEPT

No se utiliza UFW.

## Redes actualmente declaradas

    LAN_UIO       192.168.2.0/24
    BROADCAST_6   192.168.6.0/24
    CORP_28       192.168.28.0/24

## Orden de arranque

    wg-quick@wg0.service
            |
            v
    wireguardvpn-firewall.service

El firewall se genera despues de levantar wg0.

## Reload

Los cambios de roles o politicas pueden aplicarse mediante:

    sudo systemctl reload wireguardvpn-firewall.service

sin reiniciar WireGuard.

## Estado esperado tras reboot

    wg0                         active
    wireguardvpn-firewall       active
    UDP/51820                   listening
    WG-INPUT                    presente
    WG-FORWARD                  presente
    WG-NAT                      presente
