# Developer Documentation — Inception

## Prerequisites

- Linux VM (Ubuntu/Debian recommended)
- Docker Engine 24+ with Compose V2 plugin
- `make`
- `git`
- Root/sudo access (for Docker)

## Project Structure

```
Inception/
├── Makefile                        # Build orchestration
├── secrets/                        # Docker secrets (gitignored)
│   ├── mysql.txt                   # MariaDB maintenance password
│   ├── wp_db.txt                   # WordPress DB user password
│   ├── wp_admin.txt                # WordPress admin password
│   ├── wp_user.txt                 # WordPress regular user password
│   ├── ftp.txt                     # FTP user password
│   └── portainer.txt               # Portainer admin password
├── data/                           # Persistent volume data (gitignored)
│   ├── mariadb/                    # MariaDB data files
│   ├── wordpress/                  # WordPress website files
│   └── portainer/                  # Portainer config/data
└── srcs/
    ├── .env                        # Environment variables
    ├── docker-compose.yml          # Service definitions, volumes, networks
    └── requirements/
        ├── nginx/                  # TLS reverse proxy + SNI routing
        │   ├── Dockerfile
        │   ├── conf/
        │   │   ├── nginx.conf      # HTTP server block (port 4443)
        │   │   ├── forward.conf    # Stream block (port 443, SNI routing)
        │   │   └── log.conf        # Stream access log format
        │   └── .dockerignore
        ├── wordpress/              # PHP-FPM application server
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── php-fpm.conf    # PHP-FPM pool config
        │   ├── tools/
        │   │   └── entrypoint.sh   # Wait for MariaDB, install WP, configure Redis
        │   └── .dockerignore
        ├── mariadb/                # Database server
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── maria.cnf       # Bind address, socket, skip DNS
        │   ├── tools/
        │   │   └── entrypoint.sh   # Secure install, create maintenance user
        │   └── .dockerignore
        └── bonus/
            ├── redis/              # Object cache
            │   ├── Dockerfile
            │   └── conf/
            │       └── redis.conf  # Bind all, no persistence, 256mb LRU
            ├── ftp/                # File transfer
            │   ├── Dockerfile
            │   └── tools/
            │       └── entrypoint.sh  # Create FTP user, start pure-ftpd
            ├── website/            # Static HTML/CSS site
            │   ├── Dockerfile
            │   ├── conf/
            │   │   └── Caddyfile.conf  # SNI-based subdomain routing
            │   ├── tools/
            │   │   ├── index.html
            │   │   └── style.css
            │   └── .dockerignore
            ├── adminer/            # DB management UI
            │   ├── Dockerfile
            │   ├── conf/
            │   │   └── index.php   # Auto-redirect to Adminer
            │   └── tools/
            │       └── entrypoint.sh  # Start PHP built-in server
            └── portainer/          # Container management UI
                └── Dockerfile      # Downloads Portainer binary
```

## Environment Setup

### 1. Create Docker secrets

```bash
mkdir -p secrets
echo "strong_mysql_password"   > secrets/mysql.txt
echo "strong_wp_db_password"   > secrets/wp_db.txt
echo "strong_wp_admin_password"> secrets/wp_admin.txt
echo "strong_wp_user_password" > secrets/wp_user.txt
echo "strong_ftp_password"     > secrets/ftp.txt
echo "strong_portainer_password"> secrets/portainer.txt
chmod 600 secrets/*
```

### 2. Configure environment variables

Edit `srcs/.env`:

```bash
DOMAIN_NAME=login.42.fr     # Replace with your 42 login
WP_PATH=/var/www/html
WP_TITLE=Inception
WP_ADMIN_USER=supervisor     # Must not contain "admin"
WP_ADMIN_EMAIL=admin@42.fr
WP_USER=minion
WP_USER_EMAIL=minion@42.fr
WP_DB=wordpress
WP_DB_USER=wp
MYSQL_USER=boss
FTP_USER=ftpu
FTP_PASSIVE_IP=172.18.0.1   # Docker bridge gateway IP
```

### 3. Configure DNS

Add to `/etc/hosts` on the host VM:
```
127.0.0.1   login.42.fr static.login.42.fr data.login.42.fr manage.login.42.fr
```

## Building and Launching

```bash
make              # Build all images + start all containers (detached)
```

This runs:
1. `mkdir -p data/mariadb data/wordpress data/portainer` (host volume directories)
2. `docker compose build` (builds all Dockerfiles)
3. `docker compose up -d` (starts all containers)

### Build a specific service only

```bash
make nginx         # Build + start nginx only
make wordpress     # Build + start wordpress only
```

### Debug build (full output)

```bash
make debug
```

## Container Management

| Command | Effect |
|---|---|
| `make` | Build + start everything |
| `make down` | Stop + remove containers and networks. Volumes and images are preserved. |
| `make stop` | Stop containers without removing them |
| `make start` | Start stopped containers without rebuilding |
| `make clean` | Remove containers, volumes, and prune build cache older than 48h |
| `make fclean` | Remove everything: containers, volumes, images, build cache |
| `make re` | Full rebuild: `remove` then `run` |
| `make remove` | Remove containers, images, volumes for specified services |
| `make sh <svc>` | Shell into a running container (`docker compose exec`) |
| `make logs` | Follow logs from all containers (loops to reconnect) |
| `make ps` | Show container status |
| `make du` | Show Docker disk usage |

## Data Persistence

### Named Volumes

| Volume | Container Path | Host Path | Contents |
|---|---|---|---|
| `database-disk` | `/var/lib/mysql` | `data/mariadb` | MariaDB data files |
| `wordpress-disk` | `/var/www/html` | `data/wordpress` | WordPress files, themes, uploads |
| `portainer-disk` | `/data` | `data/portainer` | Portainer config and state |

Volumes use the Docker `local` driver with bind-mount backend to persist data at known host paths.

### Data lifecycle

- `make down` — containers removed, **data preserved**
- `make clean` — containers + volumes removed, host `data/` directories deleted
- `make fclean` — everything removed including Docker images

### MariaDB initialization

First run only:
1. Starts temporary `mariadbd` with `--skip-networking`
2. Runs secure installation (unix_socket auth, remove anonymous users, disable remote root)
3. Creates maintenance user (`boss`) with credentials from `secrets/mysql.txt`
4. Shuts down temporary server
5. Writes `/var/lib/mysql/.init_completed` flag file

Subsequent runs skip initialization and start `mariadbd` directly.

### WordPress initialization

First run only:
1. Waits for MariaDB to accept connections
2. Creates database and grants for the WP user
3. Generates `wp-config.php` via WP-CLI
4. Installs WordPress core
5. Creates admin and regular users
6. Configures Redis cache plugin
7. Starts php-fpm

Subsequent runs skip setup and start php-fpm directly.

## Service Architecture

### NGINX Stream Layer (port 443)

The stream module uses `ssl_preread` to read the SNI hostname without terminating TLS:

```
Client → :443 (stream)
  ├── login.42.fr → :4443 (nginx HTTP, TLS termination → WordPress)
  ├── *.login.42.fr → Caddy :8443 (TLS termination → subdomains)
  └── unknown → :9443 (black hole, returns 404)
```

### Caddy Subdomain Routing (port 8443)

Caddy handles bonus services via subdomain-based routing:

```
static.login.42.fr → /srv/www (static HTML/CSS)
data.login.42.fr   → inception_adminer:8080
manage.login.42.fr → inception_portainer:9000
```

### Inter-Service Communication

All services communicate through `inception_network` (bridge driver) using Docker DNS:

```
NGINX      → inception_wordpress:9000  (FastCGI)
WordPress  → inception_mariadb:3306    (MySQL protocol)
WordPress  → inception_redis:6379      (Redis protocol)
Adminer    → inception_mariadb:3306    (MySQL protocol)
FTP        → wordpress-disk            (shared volume)
Caddy      → inception_adminer:8080    (HTTP proxy)
Caddy      → inception_portainer:9000  (HTTP proxy)
```

## Troubleshooting

| Symptom | Check |
|---|---|
| Container keeps restarting | `make logs <service>` for error output |
| WordPress shows blank page | Check PHP-FPM is running: `make sh wordpress` → `ps aux` |
| Can't connect to database | Verify MariaDB is ready: `make sh mariadb` → `mariadb -e "SELECT 1"` |
| Redis cache not working | Check Redis is reachable: `make sh redis` → `redis-cli ping` |
| FTP connection refused | Verify passive IP is correct in `.env` (must be Docker bridge gateway) |
| Subdomain returns 404 | Check DNS resolves to VM IP; check Caddyfile matches the subdomain |
| TLS certificate error | Self-signed cert is expected; accept the browser warning |
