
## Acceso administrativo

### Acceso principal

Cuando el registro DNS institucional este disponible:

    https://vpn.uio.ecuavisa.com

Puerto:

    TCP/443

### Acceso directo temporal / administrativo

Mientras el DNS institucional no este disponible:

    https://192.168.2.168:9444

El certificado incluye como SAN:

    DNS:vpn.uio.ecuavisa.com
    IP:192.168.2.168

Por tanto ambos accesos utilizan el mismo certificado institucional.

El puerto 9444 no reemplaza al acceso principal 443.

Backend FastAPI:

    127.0.0.1:8095

El backend no debe exponerse directamente a la red.

### Control de acceso

Nginx permite exclusivamente:

    10.8.0.0/24
    192.168.2.0/24
    192.168.6.0/24
    192.168.28.0/24

Ademas requiere HTTP Basic Authentication sobre HTTPS.
