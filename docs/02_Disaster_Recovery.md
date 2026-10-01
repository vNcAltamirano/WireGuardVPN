# Disaster Recovery — WireGuardVPN

## Prioridad de recuperacion

1. Red de videosrv.
2. WireGuard wg0.
3. Firewall WireGuard.
4. Dashboard FastAPI.
5. Nginx HTTPS.
6. Prueba con un cliente real.

## Servicios

    wg-quick@wg0
    wireguardvpn-firewall.service
    wireguardvpn-dashboard.service
    nginx

## Verificacion minima

    systemctl is-active wg-quick@wg0
    systemctl is-active wireguardvpn-firewall.service
    systemctl is-active wireguardvpn-dashboard.service
    systemctl is-active nginx

## Puertos

    UDP 51820      WireGuard
    TCP 443        Dashboard por DNS
    TCP 9444       Dashboard directo
    TCP 8095       FastAPI solo localhost

8095 nunca debe quedar publicado en 0.0.0.0.

## Secrets necesarios para recovery

    /etc/wireguard/wg0.conf
    /etc/wireguard/server_private.key
    /etc/wireguard/server_public.key
    /etc/wireguard/peers/
    /etc/nginx/ssl/wireguardvpn/
    /etc/nginx/auth/wireguardvpn.htpasswd

## Configuracion runtime necesaria

    /etc/systemd/system/wireguardvpn-firewall.service
    /etc/systemd/system/wireguardvpn-dashboard.service
    /etc/sudoers.d/wireguardvpn-dashboard
    /usr/local/sbin/wireguardvpn-admin
    /etc/nginx/sites-available/wireguardvpn.conf

## Proyecto

    /srv/WireGuardVPN

El repositorio Git NO contiene las claves privadas.

Por tanto Git por si solo NO es un backup completo.

## Comprobacion post recovery

    sudo wg show wg0 listen-port

Debe devolver:

    51820

Luego:

    curl -fsS http://127.0.0.1:8095/health

Debe devolver:

    {"status":"ok"}

Finalmente validar un peer real.
