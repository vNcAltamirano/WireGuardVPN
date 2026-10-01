# Índice de documentación — WireGuardVPN Ecuavisa UIO

Estado: Producción  
Release base: `v1.0.0`

## Documentos principales

### `../README.md`

Presentación del proyecto, arquitectura resumida, operación rápida y
referencias principales.

### `../PROJECT_CONTEXT.md`

Fuente de contexto técnico completa para mantenimiento, evolución,
incidencias y continuidad del proyecto.

---

## Instalación y configuración

### `02_Instalacion.md`

Instalación inicial de dependencias y estructura base.

### `03_Configuracion_Servidor.md`

Configuración de WireGuard en `videosrv`.

---

## Gestión y acceso

### `04_Gestion_Peers.md`

Alta, gestión, regeneración y revocación de peers.

### `05_Android.md`

Uso y pruebas desde clientes Android.

### `05_Control_Acceso.md`

Modelo de control de acceso y roles.

### `06_Persistencia_RBAC.md`

Persistencia del firewall, roles y políticas RBAC.

---

## Arquitectura y operación de producción

### `01_Arquitectura_y_Operacion.md`

Arquitectura final, redes, servicios, roles, seguridad y operación.

### `07_Dashboard_HTTPS.md`

Dashboard FastAPI, Nginx, HTTPS, TLS, autenticación y controles de
acceso.

### `02_Disaster_Recovery.md`

Backup, recuperación y validación posterior a una incidencia.

---

## Branding

### `../branding/BRANDING_GUIDE.md`

Sistema visual reutilizable Ecuavisa UIO.

---

## Herramientas operativas

Estado general:

    ../tools/status.sh

Auditoría documental:

    ../tools/docs_audit.sh

Backup:

    ../scripts/backup.sh

Snapshot de contexto:

    ../scripts/project_context_snapshot.sh

---

## Documentación dinámica

Generar antes de una intervención importante:

    ./scripts/project_context_snapshot.sh

Salida:

    context_snapshot.txt

`context_snapshot.txt` no se versiona.

---

## Regla de mantenimiento documental

Cuando cambie cualquiera de estos elementos:

- direcciones IP;
- redes;
- rutas;
- puertos;
- roles;
- WireGuard;
- firewall;
- dashboard;
- Nginx;
- TLS;
- systemd;
- sudoers;
- privilege broker;
- backup o recuperación;

revisar como mínimo:

    README.md
    PROJECT_CONTEXT.md
    docs/00_Indice.md
    documento técnico específico afectado

Y posteriormente ejecutar:

    ./tools/docs_audit.sh
