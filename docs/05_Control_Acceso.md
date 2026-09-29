# 05 - Control de Acceso WireGuard

## Objetivo

Aplicar autorizacion por peer sin modificar las politicas globales
de firewall del servidor `videosrv`.

## Cadenas dedicadas

Se crean:

    WG-INPUT
    WG-FORWARD

Solo el trafico proveniente de:

    wg0

es enviado a estas cadenas.

## Politica

La politica global de INPUT y FORWARD del host no se modifica.

El modelo WireGuard utiliza:

    default deny

dentro de las cadenas dedicadas.

## Peer validado

Peer:

    android-vnc-01

VPN IP:

    10.8.0.2

Rol:

    server-only

## Acceso permitido

El peer puede acceder a servicios locales del propio `videosrv`.

Adicionalmente se autoriza DNS corporativo:

    192.168.2.10
    UDP 53
    TCP 53

## Acceso bloqueado

El peer no puede utilizar `videosrv` como gateway hacia otras redes.

Se verifico que trafico desde:

    10.8.0.2

hacia equipos remotos de:

    192.168.2.0/24

es bloqueado por:

    WG-FORWARD

## Validacion

Los contadores del firewall confirmaron:

    WG-INPUT  -> ACCEPT hacia videosrv
    WG-FORWARD -> DROP hacia LAN

La prueba demuestra aislamiento real por peer.

## Rollback

Snapshot previo:

    backups/iptables-before-phase4.rules

Restauracion:

    sudo ./scripts/firewall_rollback.sh

## DNS corporativo

Servidor DNS:

    192.168.2.10

Validado:

    apuntadores.uio.ecuavisa.com
        -> videosrv.ecuavisa.com
        -> 192.168.2.168

El DNS interno tambien resuelve dominios publicos.

Por tanto los peers WireGuard pueden utilizar:

    DNS = 192.168.2.10

sin perder resolucion de Internet.

El acceso DNS se limita mediante firewall a:

    UDP 53
    TCP 53
