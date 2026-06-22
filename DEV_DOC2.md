# Developer Documentation

This document describes how to set up the Inception project from scratch, build it, and manage it as a developer.

## Environment Setup

### Prerequisites

Before starting, ensure you have the following installed:

- **Operating System**: Virtual Machine (required by 42 curriculum)
- **Docker**: Version 20 or higher
- **Docker Compose**: Version 2 or higher (v1 is not supported)
- **Git**: For cloning the repository
- **Resources**: Minimum 4GB RAM, 2 CPU cores recommended

Verify your environment:
```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Verify Docker is running
docker info
```

### Project Structure

```
Inception/
├── Makefile                          # Main build/management file
├── secrets/                          # Docker secrets (6 files)
│   ├── ftp.txt
│   ├── mysql.txt
│   ├── portainer.txt
│   ├── wp_admin.txt
│   ├── wp_db.txt
│   └── wp_user.txt
├── srcs/
│   ├── .env                          # Environment variables
│   ├── docker-compose.yml            # Service definitions
│   └── requirements/
│       ├── nginx/                   # Reverse proxy with TLS
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   └── conf/
│       │       ├── nginx.conf
│       │       ├── forward.conf
│       │       └── log.conf
│       ├── wordpress/               # WordPress + PHP-FPM
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── conf/
│       │   │   └── php-fpm.conf
│       │   └── tools/
│       │       └── entrypoint.sh
│       ├── mariadb/                 # Database server
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── conf/
│       │   │   └── maria.cnf
│       │   └── tools/
│       │       └── entrypoint.sh
│       └── bonus/
│           ├── adminer/
│           │   ├── Dockerfile
│           │   ├── conf/
│           │   │   └── index.php
│           │   └── tools/
│           │       └── entrypoint.sh
│           ├── ftp/
│           │   ├── Dockerfile
│           │   └── tools/
│           │       └── entrypoint.sh
│           ├── portainer/
│           │   └── Dockerfile
│           ├── redis/
│           │   ├── Dockerfile
│           │   └── conf/
│           │       └── redis.conf
│           └── website/
│               ├── Dockerfile
│               ├── .dockerignore
│               ├── conf/
│               │   └── Caddyfile.conf
│               └── tools/
│                   ├── index.html
│                   └── style.css
└── data/                            # Persistent volumes (gitignored)
    ├── mariadb/
    ├── portainer/
    └── wordpress/
```

### Clone the Repository

```bash
git clone <repository-url> Inception
cd Inception
```

### Create Docker Secrets

Create the `secrets/` directory and populate it with credential files:

```bash
mkdir -p secrets

# Create each secret file with appropriate credentials
# FTP credentials (format: username\npassword)
echo -e "ftpu\nftp_password_here" > secrets/ftp.txt

# MySQL root password
echo "mysql_root_password_here" > secrets/mysql.txt

# Portainer admin password
echo "portainer_admin_password_here" > secrets/portainer.txt

# WordPress database password
echo "wp_db_password_here" > secrets/wp_db.txt

# WordPress admin password
echo "wp_admin_password_here" > secrets/wp_admin.txt

# WordPress user password
echo "wp_user_password_here" > secrets/wp_user.txt

# Secure the secrets directory
chmod 600 secrets/*
```

**Important**: Never commit these files to Git. They should be in your `.gitignore`.

### Configure Environment Variables

Edit `srcs/.env` to match your setup:

```bash
# Domain name (must match your 42 login)
DOMAIN_NAME=mweghofe.42.fr

# WordPress configuration
WP_PATH=/var/www/html
WP_TITLE=Inception
WP_ADMIN_USER=supervisor
WP_ADMIN_EMAIL=super@inception.hehe
WP_USER=minion
WP_USER_EMAIL=minion@inception.hehe
WP_DB=wordpress
WP_DB_USER=wp

# MySQL configuration
MYSQL_USER=boss

# FTP configuration
FTP_USER=ftpu
FTP_PASSIVE_IP=172.18.0.1
```

### Create Data Directories

The Makefile automatically creates the `data/` directory structure:

```bash
mkdir -p data/mariadb data/wordpress data/portainer
```

Or let the Makefile handle it:
```bash
make build
```

## Building and Launching

### Using the Makefile (Recommended)

The Makefile provides convenient targets for all common operations:

| Target | Command | Description |
|--------|---------|-------------|
| `make` or `make run` | `make` | Build images and start all containers |
| `make build` | `make build` | Build Docker images only |
| `make up` | `make up` | Start containers from existing images |
| `make down` | `make down` | Stop and remove containers (keep volumes) |
| `make stop` | `make stop` | Stop containers (keep everything) |
| `make start` | `make start` | Start stopped containers |
| `make re` | `make re` | Full rebuild: remove, build, run |
| `make clean` | `make clean` | Remove containers, networks, volumes |
| `make fclean` | `make fclean` | Nuclear cleanup: remove everything |
| `make debug` | `make debug` | Build with full output for debugging |
| `make logs` | `make logs` | Follow logs from all containers |
| `make ps` | `make ps` | Show running services |
| `make du` | `make du` | Show Docker disk usage |
| `make sh <service>` | `make sh nginx` | Shell into a container |

**Standard workflow**:
```bash
# First time: build and start everything
make

# After making changes: rebuild and restart
make re

# Stop everything (keep data)
make down

# Start again
make up
```

### Using Docker Compose Directly

All Makefile targets use `docker compose -f srcs/docker-compose.yml`. You can also run commands directly:

```bash
# Build all images
docker compose -f srcs/docker-compose.yml build

# Start all services
docker compose -f srcs/docker-compose.yml up -d

# Start specific services
docker compose -f srcs/docker-compose.yml up -d inception_nginx inception_wordpress

# View logs
docker compose -f srcs/docker-compose.yml logs -f

# Execute command in container
docker compose -f srcs/docker-compose.yml exec inception_wordpress wp --version

# Stop all services
docker compose -f srcs/docker-compose.yml down

# Stop and remove with volumes
docker compose -f srcs/docker-compose.yml down -v
```

### Building Individual Services

To build a specific service:
```bash
# Build only NGINX
docker compose -f srcs/docker-compose.yml build inception_nginx

# Build and start only WordPress and its dependencies
make wordpress
```

## Managing Containers and Volumes

### Container Management

```bash
# List all containers (including stopped)
docker ps -a

# List only running containers
docker ps

# View resource usage
docker stats

# Inspect a container
docker inspect inception_nginx

# View container logs
docker logs inception_nginx

# Follow container logs
docker logs -f inception_nginx

# Restart a container
docker restart inception_nginx

# Remove a stopped container
docker rm inception_nginx
```

### Volume Management

```bash
# List all volumes
docker volume ls

# Inspect a volume
docker volume inspect inception_database-disk

# View volume contents (via container)
docker compose -f srcs/docker-compose.yml exec inception_wordpress ls -la /var/www/html

# Remove unused volumes
docker volume prune
```

### Network Management

```bash
# List networks
docker network ls

# Inspect the custom network
docker network inspect inception_inception_network

# Test connectivity between containers
docker compose -f srcs/docker-compose.yml exec inception_wordpress ping inception_mariadb
```

### Image Management

```bash
# List all images
docker images

# Remove unused images
docker image prune

# Remove specific image
docker rmi inception_nginx

# View image history
docker history inception_nginx
```

## Data Storage and Persistence

### Volume Configuration

The project uses **named volumes** with a **bind mount backend** for persistence:

```yaml
# From docker-compose.yml
volumes:
  database-disk:
    driver: local
    driver_opts:
      type: none
      device: ../data/mariadb
      o: bind
  wordpress-disk:
    driver: local
    driver_opts:
      type: none
      device: ../data/wordpress
      o: bind
  portainer-disk:
    driver: local
    driver_opts:
      type: none
      device: ../data/portainer
      o: bind
```

### Volume Mount Points

| Volume | Container Mount | Host Path | Purpose |
|--------|------------------|-----------|---------|
| `database-disk` | `/var/lib/mysql` | `../data/mariadb` | MariaDB database files |
| `wordpress-disk` | `/var/www/html` | `../data/wordpress` | WordPress website files |
| `portainer-disk` | `/data` | `../data/portainer` | Portainer configuration |

### How Persistence Works

1. **Named volumes** are created by Docker Compose
2. **Bind mounts** map these volumes to host directories (`../data/`)
3. Data written to container paths persists on the host
4. Volumes survive container restarts and rebuilds
5. Only `fclean` or manual volume removal deletes persistent data

### Accessing Persistent Data

```bash
# View WordPress files on host
ls -la data/wordpress/

# View database files on host
ls -la data/mariadb/

# Backup WordPress data
tar -czvf wordpress_backup.tar.gz data/wordpress/

# Restore WordPress data
tar -xzvf wordpress_backup.tar.gz -C data/
```

### Docker Socket Access

Portainer requires access to the Docker socket to manage containers:

```yaml
# From docker-compose.yml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

This mount allows Portainer to interact with the Docker daemon on the host.
