# Developer Documentation — Inception

This document covers everything needed to set up, build, run, and maintain the project as a developer: environment setup from scratch, the Makefile/Compose internals, container and volume management, data persistence, and the internal architecture of each service.

For the high-level pitch, diagram, and design-choice comparisons, see [README.md](README.md). For day-to-day usage (starting the stack, accessing services, credentials, health checks), see [USER_DOC.md](USER_DOC.md).

## Prerequisites

- A Linux virtual machine (the subject requires the whole stack to run inside one)
- Docker Engine with the Compose v2 plugin
- `make`
- `git`

## Project Structure

```
Inception/
├── Makefile                        # Build/run orchestration (wraps docker compose)
├── secrets/                        # Docker secrets — gitignored, created by hand (see USER_DOC.md)
│   ├── mysql.txt
│   ├── wp_db.txt
│   ├── wp_admin.txt
│   ├── wp_user.txt
│   ├── ftp.txt
│   └── portainer.txt
├── data/                           # Bind-mount backend for the named volumes — gitignored
│   ├── mariadb/
│   ├── wordpress/
│   └── portainer/
└── srcs/
    ├── .env                        # Non-secret configuration (domain, usernames, ports)
    ├── docker-compose.yml          # Services, volumes, networks, secrets
    └── requirements/
        ├── nginx/                  # TLS entry point + SNI stream routing
        │   ├── Dockerfile
        │   └── conf/
        │       ├── nginx.conf      # HTTP server block (port 4443) → WordPress
        │       ├── forward.conf    # Stream block (port 443) → SNI routing
        │       └── log.conf        # Stream access-log format
        ├── wordpress/              # WordPress + PHP-FPM (no nginx)
        │   ├── Dockerfile
        │   ├── conf/php-fpm.conf
        │   └── tools/entrypoint.sh
        ├── mariadb/                # Database server
        │   ├── Dockerfile
        │   ├── conf/maria.cnf
        │   └── tools/entrypoint.sh
        └── bonus/
            ├── redis/              # Object cache for WordPress
            │   ├── Dockerfile
            │   └── conf/redis.conf
            ├── ftp/                # Pure-FTPd, serves the WordPress volume
            │   ├── Dockerfile
            │   └── tools/entrypoint.sh
            ├── website/            # Static HTML/CSS site + Caddy (2nd reverse-proxy layer)
            │   ├── Dockerfile
            │   ├── conf/Caddyfile.conf
            │   └── tools/{index.html,style.css}
            ├── adminer/            # MariaDB web UI
            │   ├── Dockerfile
            │   ├── conf/index.php  # redirect with server/user pre-filled
            │   └── tools/entrypoint.sh
            └── portainer/          # Docker management UI
                └── Dockerfile      # downloads the Portainer release binary
```

## Environment Setup From Scratch

### 1. Clone the repository

```bash
git clone <repository_url> Inception && cd Inception
```

### 2. Create the Docker secrets

The subject requires no credential to ever appear in a Dockerfile, in `docker-compose.yml`, or in git. Every password is a [Docker secret](https://docs.docker.com/engine/swarm/secrets/) — a file under `secrets/` mounted at `/run/secrets/<name>` inside only the container(s) that need it. `secrets/` is gitignored and must be created by hand; each file holds exactly one line, the password:

```bash
mkdir -p secrets
printf '%s' 'your_mariadb_maintenance_password' > secrets/mysql.txt
printf '%s' 'your_wordpress_db_password'        > secrets/wp_db.txt
printf '%s' 'your_wordpress_admin_password'     > secrets/wp_admin.txt
printf '%s' 'your_wordpress_user_password'      > secrets/wp_user.txt
printf '%s' 'your_ftp_password'                 > secrets/ftp.txt
printf '%s' 'your_portainer_admin_password'     > secrets/portainer.txt
chmod 600 secrets/*.txt
```

These are declared as top-level `secrets:` in `docker-compose.yml` and attached per-service:

```yaml
# srcs/docker-compose.yml
secrets:
  ftp:
    file: ../secrets/ftp.txt
  mysql:
    file: ../secrets/mysql.txt
  portainer:
    file: ../secrets/portainer.txt
  wp_db:
    file: ../secrets/wp_db.txt
  wp_admin:
    file: ../secrets/wp_admin.txt
  wp_user:
    file: ../secrets/wp_user.txt
```

See [USER_DOC.md § Creating and Managing Credentials](USER_DOC.md#creating-and-managing-credentials) for what each file controls.

### 3. Configure `srcs/.env`

`.env` holds every *non-sensitive* setting — the subject mandates a `.env` file for environment variables, separate from secrets:

```ini
DOMAIN_NAME=mweghofe.42.fr   # your 42 login + .42.fr
WP_PATH=/var/www/html
WP_TITLE=Inception
WP_ADMIN_USER=supervisor     # must NOT contain admin/Admin/administrator/Administrator
WP_ADMIN_EMAIL=super@inception.hehe
WP_USER=minion
WP_USER_EMAIL=minion@inception.hehe
WP_DB=wordpress
WP_DB_USER=wp
MYSQL_USER=boss              # MariaDB maintenance user, created on first boot
FTP_USER=ftpu
FTP_PASSIVE_IP=172.18.0.1    # the Docker bridge gateway IP — needed for passive FTP
```

`DOMAIN_NAME` is baked into the NGINX/Caddy configs and TLS certificate `CN` at **build time** (via Dockerfile `ARG`s), so changing it requires a rebuild (`make re`), not just a container restart.

### 4. DNS / hosts

Point `DOMAIN_NAME` and its subdomains (`static.`, `data.`, `manage.`) at the VM's IP — from the client machine, that usually means editing `/etc/hosts` rather than owning real DNS.

## Build & Launch

### Using the Makefile

```bash
make              # mkdir -p data/*, docker compose build, docker compose up -d — everything
make <service>    # build & start one service, e.g. `make nginx` (also brings up its dependencies)
make debug        # same as `make`, but with full (--progress=plain) build output
```

`make`/`make run`/`make all`/`make up` are all equivalent entry points (`up` depends on `build`, which first creates the `data/` directories used as the volumes' bind-mount backend).

### Using Docker Compose directly

Every Makefile target is a thin wrapper around `docker compose -f srcs/docker-compose.yml`, so you can always drop down a level:

```bash
docker compose -f srcs/docker-compose.yml build [service...]
docker compose -f srcs/docker-compose.yml up -d [service...]
docker compose -f srcs/docker-compose.yml logs -f [service...]
docker compose -f srcs/docker-compose.yml exec inception_wordpress sh
```

### Building a single service

```bash
make nginx        # only nginx (+ its dependency, wordpress, per depends_on)
```

`KNOWN_SERVICES` in the Makefile is the allow-list of valid service arguments (`nginx wordpress mariadb ftp adminer portainer website redis`); anything else is rejected with a usage message.

## Managing Containers and Volumes

| Command | Effect |
|---|---|
| `make` | Build every image and start the whole stack, detached |
| `make down [service]` | Stop and remove containers/network — **keeps** volumes and images |
| `make stop [service]` | Stop containers without removing them |
| `make start [service]` | Start previously-stopped containers, no rebuild |
| `make re` | `remove` then `run` — full rebuild from a clean slate |
| `make clean [service]` | `down -v` (removes volumes), then prunes build cache older than 48h. **Only wipes `data/*` on disk** when called with no service argument (or with both `mariadb` and `wordpress` named) |
| `make remove [service]` | Like `clean`, but also removes images (`--rmi all`) |
| `make fclean` | Removes everything unconditionally: containers, volumes, images, all of `data/*`, and all build cache |
| `make sh <service>` | Interactive shell in exactly one running container |
| `make logs [service]` | Follow logs (auto-reconnects if the compose command exits) |
| `make ps` / `make psw` | Show / continuously watch container status |
| `make du` / `make duw` | Show / continuously watch Docker disk usage |

Container/volume/network management commands that aren't wrapped by the Makefile:

```bash
docker ps -a                                    # all containers, including stopped
docker inspect inception_nginx                  # full container config
docker volume ls                                # list volumes, incl. database-disk/wordpress-disk/portainer-disk
docker volume inspect inception_database-disk    # see the bind-mount backend path
docker network inspect inception_inception_network
docker compose -f srcs/docker-compose.yml exec inception_wordpress ping inception_mariadb
```

All services use `restart: always`, satisfying the subject's requirement that containers recover from a crash without manual intervention — and no entrypoint uses `tail -f`, `sleep infinity`, or a shell loop as its main process; every one ends with `exec <daemon>` so the daemon becomes PID 1.

## Data Storage and Persistence

### Named volumes (bind-mount backend)

| Volume | Container path | Host path | Contents |
|---|---|---|---|
| `database-disk` | `/var/lib/mysql` | `./data/mariadb` | MariaDB data files |
| `wordpress-disk` | `/var/www/html` | `./data/wordpress` | WordPress core, themes, plugins, uploads (shared with FTP) |
| `portainer-disk` | `/data` | `./data/portainer` | Portainer's own config/state |

```yaml
# srcs/docker-compose.yml
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

Why this shape: the subject requires *named* volumes, forbids plain bind mounts, and requires the data to live at a specific, known host path — three constraints that only the `local` driver's `type: none, o: bind` option satisfies simultaneously (see [README.md § Technology comparisons](README.md#technology-comparisons)). Data lives under `./data/` (relative to the project root) rather than an absolute `/home/<login>/data`, so the project stays portable across machines.

Portainer additionally bind-mounts `/var/run/docker.sock` (not a named volume) so it can control the Docker daemon on the host.

### Data lifecycle

- `make down` — containers removed, **data preserved** on disk
- `make clean` / `make remove` (no service, or both `mariadb`+`wordpress`) — volumes removed **and** `./data/*` deleted
- `make fclean` — everything removed unconditionally, including images and build cache

### MariaDB initialization (first boot only)

`srcs/requirements/mariadb/tools/entrypoint.sh`:

1. Checks for `/var/lib/mysql/.init_completed`; if present, skips straight to step 5.
2. Starts a temporary `mariadbd --skip-networking` instance.
3. Runs a manual secure-installation (enable `unix_socket` auth for root, drop anonymous users, disallow remote root, drop the `test` database).
4. Creates the `boss` maintenance user (password from `secrets/mysql.txt`) with broad grants, used by WordPress/Adminer to manage the `wordpress` database.
5. Shuts the temporary instance down, writes the `.init_completed` flag, then `exec mariadbd --user=mysql` as PID 1.

### WordPress initialization (first boot only)

`srcs/requirements/wordpress/tools/entrypoint.sh`:

1. Waits (polling every 2s) until MariaDB accepts connections.
2. If `wp-config.php` doesn't exist yet (first boot signal): creates the `wordpress` database and the WordPress DB user (`WP_DB_USER`, password from `secrets/wp_db.txt`), generates `wp-config.php`, runs `wp core install` with the admin user/password (`secrets/wp_admin.txt`), creates the second required user (`WP_USER`, `secrets/wp_user.txt`, `author` role), and configures the Redis object-cache plugin.
3. `exec php-fpm83 -F` as PID 1 either way.

## Service Architecture

### NGINX stream layer (port 443)

`srcs/requirements/nginx/conf/forward.conf` uses `ssl_preread` to read the TLS SNI hostname *without* terminating TLS, then routes purely on that hostname:

```nginx
# srcs/requirements/nginx/conf/forward.conf
upstream caddy_ {
	server inception_website:8443;
}

map $ssl_preread_server_name $backend {
	__DOMAIN_NAME__ 127.0.0.1:4443;
	~^.+\.__DOMAIN_NAME__ caddy_;
	default 127.0.0.1:9443;
}

server {
    listen 443;
    proxy_pass $backend;
	ssl_preread on;
}

# black hole: accepts and immediately closes
server {
    listen 127.0.0.1:9443;
	return "404";
}
```

`mweghofe.42.fr` goes to NGINX's own HTTP server on `:4443` (TLS terminated there, FastCGI to `inception_wordpress:9000`); any `*.mweghofe.42.fr` goes to Caddy on `:8443`; anything else hits the black hole on `:9443` and gets a bare `404`. `__DOMAIN_NAME__` placeholders are substituted with `sed` at build time from the `.env`-derived `ARG`.

### Caddy subdomain layer (port 8443)

`srcs/requirements/bonus/website/conf/Caddyfile.conf` terminates TLS a second time (self-signed via `tls internal`) and reverse-proxies by subdomain:

```nginx
# srcs/requirements/bonus/website/conf/Caddyfile.conf
*.__DOMAIN_NAME__:8443 {
	tls internal
	tls {
        protocols tls1.2 tls1.3
    }

    @static_website host static.__DOMAIN_NAME__
	@adminer host data.__DOMAIN_NAME__
	@portainer host manage.__DOMAIN_NAME__

    handle @static_website {
		root * /srv/www
    	file_server
    }
	handle @adminer {
		reverse_proxy inception_adminer:8080
    }
	handle @portainer {
		reverse_proxy inception_portainer:9000
    }
	handle {
        respond "no page for this URL" 200
    }
}
```

### Inter-service communication

Every service resolves the others by container name over `inception_network` (bridge driver); only NGINX (443) and the FTP server (21, 21000-21010) publish ports to the host — everything else uses `expose` (container-to-container only):

| From | To | Protocol |
|---|---|---|
| NGINX | `inception_wordpress:9000` | FastCGI |
| WordPress | `inception_mariadb:3306` | MySQL |
| WordPress | `inception_redis:6379` | Redis |
| Adminer | `inception_mariadb:3306` | MySQL (user enters credentials in the web UI) |
| Caddy | `inception_adminer:8080`, `inception_portainer:9000` | HTTP |
| FTP | `wordpress-disk` (shared volume) | — |
| Portainer | `/var/run/docker.sock` (bind mount) | Docker API |

## Troubleshooting

| Symptom | Check |
|---|---|
| Container keeps restarting | `make logs <service>` for the error, `make sh <service>` to poke around if it stays up long enough |
| WordPress shows a blank page or 502 | `make sh wordpress` → `ps aux` to confirm `php-fpm83` is running |
| "Can't connect to database" | `make sh mariadb` → `mariadb -e "SELECT 1"`; confirm `secrets/wp_db.txt` matches what was used on MariaDB's first boot |
| Redis cache not applied | `make sh redis` → `redis-cli ping` → expect `PONG`; check the WordPress entrypoint logs for the `wp redis enable` step |
| FTP connection refused | Confirm `FTP_PASSIVE_IP` in `.env` is actually the Docker bridge gateway IP, and that 21/21000-21010 are reachable |
| Subdomain returns the Caddy fallback ("no page for this URL") | The hostname doesn't match any `@`-matcher in the Caddyfile — check DNS/`/etc/hosts` and the exact subdomain |
| TLS certificate warning | Expected — every certificate in this stack is self-signed |

## Known Trade-offs

- Volumes use the `local` driver's bind-mount backend (`type: none, o: bind`) rather than a "pure" named volume — see [README.md § Technology comparisons](README.md#technology-comparisons) for why this is the only configuration that satisfies the subject's constraints.
- Host paths for volumes are relative (`./data/`) instead of an absolute `/home/<login>/data`, to keep the repository portable across machines.
