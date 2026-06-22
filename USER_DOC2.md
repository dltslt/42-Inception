# User Documentation

This document explains how to use and interact with the Inception Docker stack from an end-user or administrator perspective.

## Services Overview

The Inception stack provides the following services:

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **WordPress** | https://mweghofe.42.fr | 443 | Main website and content management system |
| **Static Website** | https://static.mweghofe.42.fr | 443 | Showcase/static content site served by Caddy |
| **Adminer** | https://data.mweghofe.42.fr | 443 | Database management web interface |
| **Portainer** | https://manage.mweghofe.42.fr | 443 | Docker container management web interface |
| **FTP Server** | ftp://mweghofe.42.fr | 21 (passive: 21000-21010) | File transfer service for WordPress content |

### Service Architecture

- **Primary Entry**: All HTTPS traffic enters through NGINX on port 443
- **Routing**: NGINX uses SNI to route traffic:
  - `mweghofe.42.fr` → WordPress (via NGINX HTTP on port 4443)
  - `*.mweghofe.42.fr` → Caddy (on port 8443) for subdomain handling
- **Subdomain Routing**: Caddy routes subdomains to appropriate services:
  - `static.mweghofe.42.fr` → Static website files
  - `data.mweghofe.42.fr` → Adminer
  - `manage.mweghofe.42.fr` → Portainer

## Starting and Stopping the Project

### Start the Entire Stack

```bash
make
# or
make run
# or
make up
```

This command:
- Builds all Docker images (if not already built)
- Creates and starts all containers in detached mode
- Sets up the custom network and volumes

### Stop the Stack (Keep Data)

```bash
make down
```

Stops and removes all containers and networks, but **preserves volumes** (your WordPress data and database remain intact).

### Stop Individual Services

```bash
make stop
```

Stops all containers without removing them. Useful for temporary maintenance.

### Start Previously Stopped Containers

```bash
make start
```

Starts all stopped containers without rebuilding.

### Full Cleanup

```bash
# Remove containers, networks, and volumes
make clean

# Remove everything including images
make fclean
```

**Warning**: `fclean` will delete all data. Use with caution.

## Accessing Services

### WordPress Website

- **URL**: https://mweghofe.42.fr
- **Access**: Open in any web browser
- **Features**: Full WordPress CMS with custom themes and plugins

### WordPress Administration

- **URL**: https://mweghofe.42.fr/wp-admin
- **Users**:
  - Administrator: `supervisor` (configured in `.env`)
  - Regular user: `minion` (configured in `.env`)
- **Note**: Credentials are managed via Docker secrets

### Static Website

- **URL**: https://static.mweghofe.42.fr
- **Access**: Open in any web browser
- **Content**: Showcase site with service overview and architecture information

### Adminer (Database Management)

- **URL**: https://data.mweghofe.42.fr
- **Access**: Open in any web browser
- **Purpose**: Web-based database management for MariaDB
- **Connection Details**:
  - System: MySQL/MariaDB
  - Server: `inception_mariadb` (use the service name as hostname)
  - Username: `boss` (configured in `.env` as `MYSQL_USER`)
  - Password: Stored in Docker secret `mysql.txt`
  - Database: `wordpress`

### Portainer (Docker Management)

- **URL**: https://manage.mweghofe.42.fr
- **Access**: Open in any web browser
- **Purpose**: Web-based Docker container management UI
- **Features**:
  - View running containers
  - Inspect container logs
  - Manage images and volumes
  - Execute commands in containers

### FTP Server

- **Server**: ftp://mweghofe.42.fr
- **Port**: 21 (control), 21000-21010 (passive data range)
- **Protocol**: FTP (not SFTP)
- **Purpose**: File transfer access to WordPress volume
- **Root Directory**: Mounts the same volume as WordPress (`/var/www/html`)
- **Note**: Credentials stored in Docker secret `ftp.txt`

## Locating and Managing Credentials

All sensitive credentials are stored as **Docker secrets** and are **never** hardcoded in Dockerfiles or committed to Git.

### Secret Files Location

Docker secrets are mounted from files in:
```
secrets/
├── ftp.txt              # FTP server credentials
├── mysql.txt            # MariaDB root password
├── portainer.txt        # Portainer admin password
├── wp_admin.txt         # WordPress administrator password
├── wp_db.txt            # WordPress database password
└── wp_user.txt          # WordPress regular user password
```

### Environment Variables

Non-sensitive configuration is in `srcs/.env`:
```
DOMAIN_NAME=mweghofe.42.fr
WP_PATH=/var/www/html
WP_TITLE=Inception
WP_ADMIN_USER=supervisor
WP_ADMIN_EMAIL=super@inception.hehe
WP_USER=minion
WP_USER_EMAIL=minion@inception.hehe
WP_DB=wordpress
WP_DB_USER=wp
MYSQL_USER=boss
FTP_USER=ftpu
FTP_PASSIVE_IP=172.18.0.1
```

### Modifying Credentials

To change credentials:

1. **Stop the stack**: `make down`
2. **Edit the secret files** in the `secrets/` directory
3. **For WordPress users**: You may also need to update the database directly via Adminer
4. **Rebuild and restart**: `make re`

**Important**: After modifying secrets, containers must be recreated to pick up the changes.

## Checking Services Are Running

### View Container Status

```bash
# Using Makefile
make ps

# Using Docker Compose directly
docker compose -f srcs/docker-compose.yml ps
```

Expected output (all services should show `Up` status):
```
NAME                    COMMAND                  SERVICE             STATUS              PORTS
inception_nginx         "/docker-entrypoin…"   nginx               running             0.0.0.0:443->443/tcp
inception_wordpress    "docker-php-entryp…"   wordpress           running             9000/tcp
inception_mariadb      "docker-entrypoint.s…"  mariadb             running             3306/tcp
inception_redis        "docker-entrypoint.s…"  redis               running             6379/tcp
inception_ftp          "vsftpd /etc/vsftpd…"  ftp                 running             0.0.0.0:21->21/tcp, 21000-21010/tcp
inception_adminer      "/docker-entrypoin…"   adminer             running             8080/tcp
inception_portainer    "/portainer"            portainer           running             9000/tcp
inception_website      "caddy run --config …"  website             running             8443/tcp
```

### View Logs

```bash
# Follow all container logs
make logs

# View logs for a specific service
docker compose -f srcs/docker-compose.yml logs inception_nginx

# View logs with timestamps
docker compose -f srcs/docker-compose.yml logs -t
```

### Test Connectivity

```bash
# Test main website
curl -k https://mweghofe.42.fr

# Test static site
curl -k https://static.mweghofe.42.fr

# Test database connection via Adminer
curl -k https://data.mweghofe.42.fr

# Check if containers can ping each other
docker compose -f srcs/docker-compose.yml exec inception_wordpress ping inception_mariadb
```

### Shell Access for Troubleshooting

```bash
# Access a specific container shell
make sh nginx
make sh wordpress
make sh mariadb

# Check running processes in a container
docker compose -f srcs/docker-compose.yml exec inception_nginx ps aux

# Check NGINX configuration test
docker compose -f srcs/docker-compose.yml exec inception_nginx nginx -t
```

### Resource Usage

```bash
# Show Docker disk usage
make du

# Show container resource usage
docker stats
```
