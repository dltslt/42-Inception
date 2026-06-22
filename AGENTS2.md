# Inception — Project Navigation

## Directory Layout

```
Inception/
├── Makefile                        # Build orchestration
├── secrets/                        # Docker secrets (gitignored)
│   ├── ftp.txt
│   ├── mysql.txt
│   ├── portainer.txt
│   ├── wp_admin.txt
│   ├── wp_db.txt
│   └── wp_user.txt
├── srcs/
│   ├── .env                        # Environment variables
│   ├── docker-compose.yml          # Service definitions, volumes, networks
│   └── requirements/
│       ├── nginx/                  # TLS reverse proxy + SNI routing
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   └── conf/               # nginx.conf, forward.conf, log.conf
│       ├── wordpress/              # WordPress + php-fpm83
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── conf/               # php-fpm.conf
│       │   └── tools/              # entrypoint.sh
│       ├── mariadb/                # MariaDB database
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── conf/               # maria.cnf
│       │   └── tools/              # entrypoint.sh
│       └── bonus/
│           ├── redis/              # Redis object cache
│           │   ├── Dockerfile
│           │   └── conf/           # redis.conf
│           ├── ftp/                # Pure-FTPd
│           │   ├── Dockerfile
│           │   └── tools/          # entrypoint.sh
│           ├── website/            # Static HTML/CSS (Caddy)
│           │   ├── Dockerfile
│           │   ├── .dockerignore
│           │   ├── conf/           # Caddyfile.conf
│           │   └── tools/          # index.html, style.css
│           ├── adminer/            # DB management UI
│           │   ├── Dockerfile
│           │   ├── conf/           # index.php
│           │   └── tools/          # entrypoint.sh
│           └── portainer/          # Container management UI
│               └── Dockerfile
├── data/                           # Host volume data (gitignored)
├── README.md                       # Project overview + architecture
├── USER_DOC.md                     # End-user documentation
├── DEV_DOC.md                      # Developer documentation
├── AGENTS.md                       # This file
└── LOG.md                          # Session log
```

## Tech Stack

- **Container base**: Alpine 3.23 (penultimate stable)
- **Web server**: NGINX with TLSv1.2/1.3 only; stream module for SNI-based routing
- **Application**: WordPress via WP-CLI + php-fpm83
- **Database**: MariaDB with secure installation
- **Cache**: Redis (bonus) — object cache for WordPress
- **Static site**: Caddy serving HTML/CSS (bonus)
- **FTP**: Pure-FTPd (bonus)
- **DB admin**: Adminer (bonus)
- **Container mgmt**: Portainer (bonus)
- **Secrets**: Docker secrets mounted from `../secrets/*.txt`
- **Orchestration**: Docker Compose with bridge network (`inception_network`)

## Build & Run

```bash
make              # build images + start all containers
make down         # stop containers, keep volumes
make clean        # remove containers + volumes + prune cache
make fclean       # remove everything including images
make re           # full rebuild
make sh <svc>     # shell into running container
make logs         # follow logs from all containers
make debug        # build with full output
make ps           # show running services
make du           # show docker disk usage
make <service>    # build & start a specific service
```

## Architecture

Two-layer reverse proxy:
1. **Stream layer** (port 443): NGINX stream module reads SNI without terminating TLS
   - `login.42.fr` → nginx HTTP server block (port 4443) for WordPress
   - `*.login.42.fr` → Caddy (port 8443) for bonus services
   - Unknown domains → black hole (returns 404)

2. **HTTP layer**: nginx terminates TLS for WordPress; Caddy terminates TLS for subdomains

## Code Style

- Shell scripts: POSIX sh (`#!/bin/sh`), `set -e` for error handling
- No secrets hardcoded in Dockerfiles — all via Docker secrets
- Entrypoints use `exec` to replace shell with daemon (PID 1 best practice)
- No infinite loops, `tail -f`, `sleep infinity` in entrypoints
- All containers use `restart: always`

## Known Issues

- Secrets are tracked in git (must `git rm --cached` before final evaluation push)
- Named volumes use bind-mount backend (`driver_opts: type: none, o: bind`) — accepted workaround
- Volume host paths use relative `./data/` instead of absolute `/home/login/data` — intentional for cross-machine portability
