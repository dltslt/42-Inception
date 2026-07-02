*This project has been created as part of the 42 curriculum by mweghofe.*

# Inception

## Description

Inception is a small production-like infrastructure, built from scratch with Docker Compose as part of 42's system administration curriculum. Every image is built from a custom Dockerfile (no pre-built images besides the Alpine base) and orchestrated as a set of single-purpose containers on a private Docker network.

The mandatory stack serves a WordPress website (WordPress + php-fpm, MariaDB, NGINX with TLS) reachable at `https://mweghofe.42.fr`. The bonus part extends it with a Redis object cache, an FTP server, a static showcase website, Adminer, and Portainer — plus a personal addition: **Caddy as a second reverse-proxy layer**, so bonus services live on their own subdomains behind their own TLS termination rather than being bolted onto the NGINX config.

### Architecture

```mermaid
flowchart TB

    Client["🌍 Client"]

    subgraph Ingress
        Stream["NGINX Stream<br/>:443<br/>SNI Routing"]
        Http["NGINX HTTP<br/>:4443"]
        Caddy["Caddy<br/>:8443"]
    end

    subgraph Applications
        WordPress["WordPress + PHP-FPM<br/>:9000"]
        Adminer["Adminer<br/>:8080"]
        StaticSite["Static Website"]
        Portainer["Portainer<br/>:9000"]
        FTP["FTP Server<br/>:21<br/>Passive:21000-21010"]
    end

    subgraph Data
        Redis["Redis Cache<br/>:6379"]
        MariaDB["MariaDB<br/>:3306"]
    end

    subgraph Resources
        WordpressDisk["📦 wordpress-disk"]
        DatabaseDisk["📦 database-disk"]
        PortainerDisk["📦 portainer-disk"]
        DockerSocket["🐳 docker.sock"]
    end

    %% External access
    Client -->|"https://mweghofe.42.fr"| Stream
    Client -->|"ftp://mweghofe.42.fr"| FTP

    %% SNI routing
    Stream -->|"mweghofe.42.fr"| Http
    Stream -->|"*.mweghofe.42.fr"| Caddy

    %% Application routing
    Http --> WordPress

    Caddy -->|"manage.mweghofe.42.fr"| Portainer
    Caddy -->|"data.mweghofe.42.fr"| Adminer
    Caddy -->|"static.mweghofe.42.fr"| StaticSite

    %% Dependencies
    WordPress --> Redis
    WordPress --> MariaDB
    Adminer --> MariaDB

    Portainer -.-> DockerSocket

    %% Persistent storage
    FTP -.->|shared content| WordpressDisk
    WordPress -.->|website files| WordpressDisk

    MariaDB -.->|database files| DatabaseDisk
    Portainer -.->|config/data| PortainerDisk

    %% Nord Theme

    %% Subgraphs
    style Ingress fill:#EAF3F8,stroke:#81A1C1,stroke-width:2px,color:#2E3440
    style Applications fill:#EEF6EC,stroke:#A3BE8C,stroke-width:2px,color:#2E3440
    style Data fill:#FBF0EC,stroke:#D08770,stroke-width:2px,color:#2E3440
    style Resources fill:#F4EEF6,stroke:#B48EAD,stroke-width:2px,color:#2E3440

    %% Edge labels
%%{init: {
  "themeVariables": {
    "edgeLabelBackground":"#E5E9F0"
  }
}}%%

    linkStyle default color:#434C5E          

    %% Nodes
    classDef user fill:#ECEFF4,stroke:#4C566A,color:#2E3440

    classDef ingress fill:#81A1C1,stroke:#5E81AC,color:#E5E9F0
    classDef app fill:#A3BE8C,stroke:#8FBCBB,color:#2E3440
    classDef data fill:#D08770,stroke:#BF616A,color:#E5E9F0
    classDef resource fill:#B48EAD,stroke:#5E81AC,color:#E5E9F0

    classDef resource fill:#B48EAD,stroke:#5E81AC,color:#ECEFF4

    class Client user

    class Stream,Http,Caddy ingress

    class WordPress,Adminer,StaticSite,Portainer,FTP app

    class Redis,MariaDB data

    class WordpressDisk,DatabaseDisk,PortainerDisk,DockerSocket resource
```

Only port **443** is ever exposed to the outside for HTTP(S) traffic (plus 21/21000-21010 for the FTP bonus). NGINX's `stream` module reads the TLS *ClientHello* SNI field without terminating TLS, and routes purely on hostname: the bare domain goes to NGINX's HTTP server (WordPress), any subdomain goes to Caddy, and anything else is dropped by a black-hole `server` block. Caddy then terminates TLS a second time and reverse-proxies each subdomain to its bonus service. For the full breakdown of every service and container, see [DEV_DOC.md § Service Architecture](DEV_DOC.md#service-architecture).

### Main design choices

- **Alpine 3.23** (penultimate stable) as the base image for every container — small footprint, `apk` covers every package needed.
- **Two-layer reverse proxy**: NGINX `stream` for SNI-only routing, then NGINX *or* Caddy for TLS termination depending on the domain. This was chosen over cramming every bonus service into NGINX server blocks, to keep the mandatory and bonus configs fully independent.
- **Docker secrets** for every credential; **`.env`** for everything else (domain, usernames, ports) — see the comparison table below.
- **WP-CLI**, run from the entrypoint, for a fully headless WordPress install (no setup wizard).
- **Idempotent entrypoints**: each service checks for a sentinel (`.init_completed`, `wp-config.php`, an existing OS user, ...) so containers can be freely restarted or rebuilt without repeating first-run setup.

### Technology comparisons

| Aspect | Option A | Option B | Why this project uses A |
|---|---|---|---|
| **Virtualization** | Virtual Machine | Docker | A VM emulates a full guest OS through a hypervisor; a container shares the host kernel and only isolates the userland (namespaces/cgroups). That makes containers start in seconds and cost megabytes instead of gigabytes — the right trade-off for running many small, single-purpose services on one host. The whole stack still runs *inside* one VM, since that isolation boundary is required by the subject. |
| **Secrets vs Environment Variables** | Docker Secrets | `.env` variables | Secrets are mounted as files under `/run/secrets/*` inside the container only, never appear in `docker inspect`, `docker-compose.yml`, or shell history. Env vars are visible via `docker inspect`/`ps` and are easy to leak into logs. This project puts every password behind a secret and reserves `.env` for non-sensitive configuration (domain, usernames, paths). |
| **Docker Network vs Host Network** | Bridge network (`inception_network`) | Host network | `network: host`/`--link` are forbidden by the subject anyway. A dedicated bridge network isolates the stack from the host and from other Docker projects, and gives every container a resolvable DNS name (`inception_mariadb`, `inception_wordpress`, ...) so only the services that need it expose a port at all — everything else stays internal via `expose`. |
| **Docker Volumes vs Bind Mounts** | Named volumes (local driver, bind backend) | Plain bind mounts | The subject requires *named* volumes but also mandates the data live at a specific host path — two requirements that are mutually exclusive with a "pure" named volume (Docker picks the path) or a plain bind mount (no `docker volume ls` entry). The resolution is a named volume using the `local` driver with `type: none, o: bind`: Docker tracks it like any other volume, but the backing storage is pinned to `./data/<service>` on the host. |

## Instructions

### Prerequisites

- A Linux virtual machine (the subject requires the whole stack to run inside one)
- Docker Engine with the Compose v2 plugin, and `make`
- The domain `mweghofe.42.fr` (and its subdomains) resolving to the VM's IP — e.g. via `/etc/hosts` on the client machine

### Setup & run

```bash
git clone <repository_url> && cd Inception
# create the six required secret files — see USER_DOC.md#creating-the-secrets
make
```

Then open `https://mweghofe.42.fr` in a browser (self-signed certificate, expect a warning). See [USER_DOC.md](USER_DOC.md) for every service URL, default users, and how to verify everything is healthy; see [DEV_DOC.md](DEV_DOC.md) for the full `make`/`docker compose` command reference, the `.env` layout, and how project data persists on disk.

| Command | Effect |
|---|---|
| `make` | Build every image and start the whole stack (detached) |
| `make down` | Stop containers, keep volumes and images |
| `make clean` / `make fclean` | Full teardown — see [DEV_DOC.md § Managing Containers and Volumes](DEV_DOC.md#managing-containers-and-volumes) |

## Resources

### Documentation & references

- [Docker documentation](https://docs.docker.com/) & [Compose file reference](https://docs.docker.com/compose/compose-file/)
- [NGINX stream module (`ssl_preread`)](https://nginx.org/en/docs/stream/ngx_stream_ssl_preread_module.html)
- [WP-CLI command reference](https://wp-cli.org/commands/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/) — secure installation, user privileges
- [Redis configuration reference](https://redis.io/docs/management/configuration/)
- [Pure-FTPd documentation](https://www.pureftpd.org/project/pure-ftpd/doc/)
- [Caddy documentation](https://caddyserver.com/docs/) — Caddyfile, automatic TLS
- [Portainer CLI reference](https://docs.portainer.io/advanced/cli)
- [Alpine Linux packages](https://pkgs.alpinelinux.org/packages)

### AI usage

AI assistants were used throughout this project as a learning and productivity aid: explaining Docker, Compose, and Linux service concepts while the stack was being designed; reviewing the finished implementation against the subject's requirements; helping debug specific issues in entrypoint scripts and configuration files; and drafting this documentation (`README.md`, `USER_DOC.md`, `DEV_DOC.md`) based on the finished project, which was then reviewed and adjusted by hand.
