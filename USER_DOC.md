# User Documentation — Inception

## Services Overview

| **Service**      | **Purpose**                          | **Access Point**                     | **Port**  |
|------------------|--------------------------------------|-------------------------------------|-----------|
| NGINX            | Reverse proxy (TLS termination)      | `https://mweghofe.42.fr`             | 443 (SNI) |
| WordPress        | Website + php-fpm                    | `https://mweghofe.42.fr`             | 4443      |
| MariaDB          | WordPress database                   | Internal (via Docker network)       | -         |
| Redis            | Object cache for WordPress           | Internal                             | -         |
| Pure-FTPd        | FTP server (WP files)                | `ftp://mweghofe.42.fr`               | 21        |
| Caddy            | Static website + reverse proxy        | `https://*.mweghofe.42.fr`           | 8443      |
| Adminer          | Database management UI               | `https://adminer.mweghofe.42.fr`     | -         |
| Portainer        | Container management UI              | `https://portainer.mweghofe.42.fr`  | -         |

## Quick Start

### Start the Infrastructure

```bash
make
```

All containers start in detached mode. Initial build may take 5–10 minutes.

### Stop the Infrastructure

```bash
make down
```

Containers stop but volumes (data) persist.

### Full Cleanup

```bash
make clean    # Removes containers + volumes
make fclean   # Removes containers, volumes, images, and build cache
```

## Access Guide

| **Service**      | **URL**                              | **Credentials Source**               |
|------------------|--------------------------------------|-------------------------------------|
| WordPress        | `https://mweghofe.42.fr`             | `secrets/wp_admin.txt`              |
| WordPress (DB)   | Internal                             | `secrets/wp_db.txt`                 |
| Adminer          | `https://adminer.mweghofe.42.fr`     | MariaDB (see DEV_DOC.md)            |
| Portainer        | `https://portainer.mweghofe.42.fr`  | `secrets/portainer.txt`            |
| FTP              | `ftp://mweghofe.42.fr`               | `secrets/ftp.txt`                   |

> **Note**: All services use TLS. Browsers may warn about self-signed certificates.

## Credentials Management

### Locations

- **Docker Secrets**: `./secrets/*.txt` — mounted as files inside containers.
- **Environment Variables**: `./srcs/.env` — non-sensitive configuration.

### Files

| **File**                | **Purpose**                          |
|-------------------------|--------------------------------------|
| `secrets/wp_admin.txt`  | WordPress admin user + password      |
| `secrets/wp_db.txt`     | WordPress DB user + password         |
| `secrets/wp_user.txt`   | WordPress regular user + password    |
| `secrets/mysql.txt`     | MariaDB root password                |
| `secrets/ftp.txt`       | FTP username + password               |
| `secrets/portainer.txt`| Portainer admin password             |

### Updating Credentials

1. Edit the relevant file in `./secrets/` or `./srcs/.env`.
2. Rebuild and restart:

```bash
make re
```

> **Security Note**: Never commit secrets to Git. They are `.gitignore`d.

## Verification

### Check Running Services

```bash
make ps          # List running containers
make logs        # Follow all container logs
```

### Expected Output (make ps)

```
NAME                COMMAND                  PORTS                   STATUS
inception-nginx     "/entrypoint.sh"        0.0.0.0:443->443/tcp    Up
inception-wordpress "/entrypoint.sh"        9000/tcp                Up
inception-mariadb   "docker-entrypoint.s…"   3306/tcp                Up
inception-redis     "docker-entrypoint.s…"   6379/tcp                Up
inception-ftp       "/entrypoint.sh"        0.0.0.0:21->21/tcp      Up
inception-caddy     "/entrypoint.sh"        0.0.0.0:8443->8443/tcp  Up
inception-adminer   "/entrypoint.sh"        8080/tcp                Up
inception-portainer "portainer"              9000/tcp                Up
```

### Health Checks

- **WordPress**: Visit `https://mweghofe.42.fr` — should load the site.
- **Adminer**: Visit `https://adminer.mweghofe.42.fr` — should show login page.
- **Portainer**: Visit `https://portainer.mweghofe.42.fr` — should show dashboard.
- **FTP**: Connect via `ftp mweghofe.42.fr` with credentials from `secrets/ftp.txt`.

## Troubleshooting

| **Issue**                          | **Solution**                                                                 |
|------------------------------------|-----------------------------------------------------------------------------|
| `make` fails with build errors      | Run `make debug` for verbose output. Fix Dockerfiles as needed.            |
| Containers start but exit immediately | Check logs: `docker logs <container_name>`. Verify entrypoint scripts.     |
| Port 443 already in use              | Stop conflicting service: `sudo lsof -i :443`, then `kill -9 <PID>`.     |
| WordPress shows "Database Connection Error" | Verify MariaDB is running and credentials in `secrets/wp_db.txt` match those in WordPress config. |
| TLS certificate warnings            | Expected for self-signed certs. Proceed anyway or replace with valid certs. |
| FTP connection refused              | Check Pure-FTPd logs: `docker logs inception-ftp`. Verify port 21 is open. |

## Data Persistence

All critical data persists across container restarts and rebuilds:

- **WordPress Database**: Named volume → `/home/mw/data/mariadb`
- **WordPress Files**: Named volume → `/home/mw/data/wordpress`
- **Redis Cache**: Named volume → `/home/mw/data/redis`

> See [DEV_DOC.md](DEV_DOC.md) for detailed volume paths and backup instructions.
