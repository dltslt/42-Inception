# Developer Documentation — Inception

## Prerequisites

| **Tool**            | **Version**       | **Purpose**                          |
|---------------------|-------------------|--------------------------------------|
| Docker              | 24+               | Container runtime                    |
| Docker Compose      | 2+                | Orchestration                        |
| Make                | Any               | Build automation                     |
| OpenSSL             | Any               | TLS certificate generation            |

### Host Configuration

- Domain `mweghofe.42.fr` must resolve to the host machine's IP.
- Ports 443, 21, 8443 must be available.
- Host directory `/home/mw/data` must exist and be writable.

```bash
mkdir -p /home/mw/data
```

## Project Structure

```
Inception/
├── Makefile                  # Build targets
├── secrets/                  # Docker secrets (gitignored)
│   ├── ftp.txt
│   ├── mysql.txt
│   ├── portainer.txt
│   ├── wp_admin.txt
│   ├── wp_db.txt
│   └── wp_user.txt
├── srcs/
│   ├── .env                  # Environment variables
│   ├── docker-compose.yml    # Service definitions
│   └── requirements/
│       ├── nginx/            # NGINX (TLS reverse proxy)
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   └── conf/
│       │       ├── nginx.conf
│       │       ├── forward.conf
│       │       └── log.conf
│       ├── wordpress/        # WordPress + php-fpm
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── conf/
│       │   │   └── php-fpm.conf
│       │   └── tools/
│       │       └── entrypoint.sh
│       ├── mariadb/          # MariaDB
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── conf/
│       │   │   └── maria.cnf
│       │   └── tools/
│       │       └── entrypoint.sh
│       └── bonus/
│           ├── redis/        # Redis cache
│           │   ├── Dockerfile
│           │   └── conf/
│           │       └── redis.conf
│           ├── ftp/          # Pure-FTPd
│           │   ├── Dockerfile
│           │   └── tools/
│           │       └── entrypoint.sh
│           ├── website/      # Static site (Caddy)
│           │   ├── Dockerfile
│           │   ├── .dockerignore
│           │   ├── conf/
│           │   │   └── Caddyfile
│           │   └── tools/
│           │       ├── index.html
│           │       └── style.css
│           ├── adminer/      # Database management UI
│           │   ├── Dockerfile
│           │   ├── conf/
│           │   │   └── index.php
│           │   └── tools/
│           │       └── entrypoint.sh
│           └── portainer/    # Container management UI
│               └── Dockerfile
├── data/                     # Volume data (gitignored)
│   ├── mariadb/
│   ├── wordpress/
│   └── redis/
├── README.md
├── USER_DOC.md
└── DEV_DOC.md
```

## Environment Setup

### 1. Create Secrets

Create `./secrets/*.txt` files with the following content (replace values):

| **File**            | **Format**                     | **Example**                     |
|---------------------|--------------------------------|---------------------------------|
| `wp_admin.txt`      | `user:password`                | `mw:SecurePass123!`             |
| `wp_db.txt`         | `user:password`                | `wp_user:DbPass456!`            |
| `wp_user.txt`       | `user:password`                | `guest:GuestPass789!`           |
| `mysql.txt`         | `root_password`                | `RootPass123!`                  |
| `ftp.txt`           | `user:password:uid:gid`        | `mw:FtpPass123!:1000:1000`      |
| `portainer.txt`     | `admin_password`              | `PortainerPass123!`             |

> **Important**: Usernames must NOT contain `admin`, `Admin`, `administrator`, or `Administrator`.

### 2. Configure .env

Edit `./srcs/.env`:

```ini
DOMAIN_NAME=mweghofe.42.fr
MYSQL_USER=wp_user
MYSQL_DATABASE=wordpress
# Non-sensitive config only (no passwords)
```

### 3. Create Host Data Directory

```bash
mkdir -p /home/mw/data/mariadb /home/mw/data/wordpress /home/mw/data/redis
```

## Build & Launch

### Using Makefile (Recommended)

| **Target**       | **Description**                                                                 |
|------------------|---------------------------------------------------------------------------------|
| `make`           | Build images and start all containers (detached)                                |
| `make down`      | Stop containers (volumes persist)                                              |
| `make clean`     | Stop containers + remove volumes                                               |
| `make fclean`    | Remove containers, volumes, images, and build cache                            |
| `make re`        | Full rebuild (clean + make)                                                    |
| `make sh <svc>`  | Shell into running container (e.g., `make sh nginx`)                           |
| `make logs`      | Follow logs from all containers                                                |
| `make debug`     | Build with full output (verbose)                                                |
| `make ps`        | Show running services (`docker-compose ps`)                                   |
| `make du`        | Show Docker disk usage                                                        |
| `make <service>` | Build & start a specific service (e.g., `make nginx`)                          |

### Manual Docker Compose

```bash
# Build and start
docker-compose -f srcs/docker-compose.yml build
docker-compose -f srcs/docker-compose.yml up -d

# Stop
docker-compose -f srcs/docker-compose.yml down

# Shell access
docker-compose -f srcs/docker-compose.yml exec nginx sh
```

## Container Management

### Shell Access

```bash
make sh nginx      # NGINX container
make sh wordpress  # WordPress container
make sh mariadb    # MariaDB container
```

Or manually:

```bash
docker exec -it inception-nginx sh
```

### Logs

```bash
make logs            # All containers

# Individual container
docker logs inception-nginx

# Follow logs
docker logs -f inception-wordpress
```

### Restart Policies

All containers use `restart: always` — they auto-recover from crashes.

## Data Storage

### Volumes

| **Volume Name**      | **Host Path**               | **Container Path**       | **Purpose**                          |
|----------------------|-----------------------------|--------------------------|--------------------------------------|
| `mariadb_data`       | `/home/mw/data/mariadb`     | `/var/lib/mysql`         | WordPress database                   |
| `wordpress_data`     | `/home/mw/data/wordpress`   | `/var/www/html`          | WordPress files                      |
| `redis_data`         | `/home/mw/data/redis`       | `/data`                 | Redis cache                          |

### Backup

```bash
# Backup all volumes
tar -czvf inception_backup_$(date +%Y%m%d).tar.gz /home/mw/data

# Restore
rm -rf /home/mw/data/*
tar -xzvf inception_backup_20240101.tar.gz -C /
```

### Wipe Data

```bash
# WARNING: Irreversible
make clean
rm -rf /home/mw/data/*
```

## Network

- **Network Name**: `inception_network` (bridge)
- **Subnet**: Default Docker bridge subnet
- **DNS**: Containers can resolve each other by service name (e.g., `mariadb`, `wordpress`, `redis`)

## Service Details

### Mandatory Services

| **Service**  | **Image**       | **Ports**               | **Dependencies**       |
|--------------|-----------------|-------------------------|------------------------|
| nginx        | Alpine-based    | 443 (host), 4443 (int)  | wordpress, mariadb     |
| wordpress    | Alpine-based    | 9000 (int)              | mariadb, redis         |
| mariadb      | Alpine-based    | 3306 (int)              | -                      |

### Bonus Services

| **Service**  | **Image**       | **Ports**               | **Dependencies**       |
|--------------|-----------------|-------------------------|------------------------|
| redis        | Alpine-based    | 6379 (int)              | -                      |
| ftp          | Alpine-based    | 21 (host)               | wordpress_data volume  |
| caddy        | Alpine-based    | 8443 (host)             | website files          |
| adminer      | Alpine-based    | 8080 (int)              | mariadb                |
| portainer    | Official image  | 9000 (int)              | Docker socket          |

## Configuration Files

### docker-compose.yml

Defines all services, volumes, networks, and secrets. Key highlights:

```yaml
version: '3.8'
services:
  nginx:
    build: ./requirements/nginx
    ports:
      - "443:443"
    volumes:
      - wordpress_data:/var/www/html
    depends_on:
      - wordpress
    restart: always
    networks:
      - inception_network
  # ... (other services)

volumes:
  mariadb_data:
    driver_opts:
      type: none
      device: /home/mw/data/mariadb
      o: bind
  wordpress_data:
    driver_opts:
      type: none
      device: /home/mw/data/wordpress
      o: bind

networks:
  inception_network:
    driver: bridge
```

### Dockerfiles

All Dockerfiles:
- Use `alpine:3.23` as base (penultimate stable)
- Install packages via `apk add`
- Copy configuration from `conf/`
- Use `exec` in entrypoints for PID 1 best practices
- No secrets hardcoded (use Docker secrets or .env)

### Entrypoints

Entrypoints (`tools/entrypoint.sh`):
- Use `#!/bin/sh -e` for error handling
- Configure services at runtime
- Mount secrets as files
- Replace shell with daemon via `exec`
