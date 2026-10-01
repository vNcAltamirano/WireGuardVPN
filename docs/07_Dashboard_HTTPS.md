
# Dashboard HTTPS — WireGuardVPN Ecuavisa UIO

## Arquitectura

    Cliente
       |
       | HTTPS
       v
     Nginx
       |
       v
    127.0.0.1:8095
       |
     FastAPI

FastAPI no se publica directamente a la red.

## Acceso actual

    https://192.168.2.168:9444

## Acceso definitivo

Cuando exista DNS institucional:

    https://vpn.uio.ecuavisa.com

Registro requerido:

    vpn.uio.ecuavisa.com A 192.168.2.168

Puerto:

    TCP/443

## Backend

    http://127.0.0.1:8095

## Certificado

    /etc/nginx/ssl/wireguardvpn/vpn.uio.ecuavisa.com.crt

Clave:

    /etc/nginx/ssl/wireguardvpn/vpn.uio.ecuavisa.com.key

Root CA:

    /etc/nginx/ssl/wireguardvpn/ecuavisa_root.crt

SAN:

    DNS:vpn.uio.ecuavisa.com
    DNS:videosrv.ecuavisa.com
    IP:192.168.2.168

La clave privada de la Root CA institucional no debe almacenarse en
videosrv.

## Autenticación

Nginx utiliza HTTP Basic Authentication.

Archivo:

    /etc/nginx/auth/wireguardvpn.htpasswd

Permisos esperados:

    root:www-data 0640

No versionar el archivo ni mostrar su contenido.

## Allowlist

Se permite acceso desde:

    10.8.0.0/24
    192.168.2.0/24
    192.168.6.0/24
    192.168.28.0/24

El resto se rechaza.

## Seguridad adicional

La configuración incluye:

- TLS 1.2 / 1.3;
- headers de seguridad;
- protección contra framing;
- MIME sniffing protection;
- referrer policy;
- permissions policy;
- CSP;
- rate limiting;
- control de origen para POST;
- ocultación de versión Nginx.

## Listeners esperados

Nginx:

    0.0.0.0:443
    [::]:443
    0.0.0.0:9444
    [::]:9444

FastAPI:

    127.0.0.1:8095

Nunca:

    0.0.0.0:8095

## Validación

    sudo nginx -t

    curl -k -I https://192.168.2.168:9444/

Sin credenciales debe responder:

    401 Unauthorized

Con credenciales:

    curl -k \
      -u tecnico_uio \
      https://192.168.2.168:9444/health

Debe responder:

    {"status":"ok"}

## Advertencias externas

`nginx -t` puede mostrar warnings de otros virtual hosts del servidor
relacionados con:

    192.168.2.168:9094
    192.168.2.168:8891
    vnc.homes:9091

No pertenecen a WireGuardVPN y no bloquean su operación.


