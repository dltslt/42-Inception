*This project has been created as part of the 42 curriculum by mw.*

# Inception

## Description

This project sets up a Docker-based infrastructure composed of NGINX (reverse proxy with TLS), WordPress with php-fpm, and MariaDB, demonstrating containerized service orchestration. The bonus part extends this with Redis (cache), Pure-FTPd, a static website (Caddy), Adminer (DB management), and Portainer (container management).

The infrastructure uses a **two-layer reverse proxy** design: NGINX stream module for SNI-based routing on port 443, with NGINX (TLS termination for WordPress) and Caddy (TLS termination for bonus subdomains) as the HTTP layer.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      INTERNET (port 443)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 NGINX STREAM (SNI routing)                    │
│  ┌───────────────────┬───────────────────────────────────────┐│
│  │ mweghofe.42.fr     │  *.mweghofe.42.fr (bonus services)     ││
│  ▼                   ▼                                       ││
│ ┌─────────┐    ┌─────────────┐                              ││
│ │ NGINX   │    │   Caddy      │                              ││
│ │ TLS     │    │   TLS        │                              ││
│ │ port4443│    │   port8443   │                              ││
│ └────┬────┘    └───────┬─────┘                              ││
└──────┼───────────────────┼──────────────────────────────────┘
       │                   │
       ▼                   ▼
┌──────────────┐   ┌─────────────────────────────────────────┐
│   WordPress  │   │  Bonus Services:                          │
│   + php-fpm │   │   - Redis (cache)                          │
└──────┬──────┘   │   - FTP (Pure-FTPd)                        │
       │          │   - Static Website (Caddy)                 │
       ▼          │   - Adminer (DB management UI)             │
┌──────────────┐   │   - Portainer (container management UI)  │
│   MariaDB     │   └─────────────────────────────────────────┘
└──────────────┘
```

## Technical Choices

| **Aspect**               | **Choice**               | **Rationale**                                                                                     |
|--------------------------|--------------------------|--------------------------------------------------------------------------------------------------|
| **Virtual Machines vs Docker** | Docker              | Containers are lightweight, share the host OS kernel, and provide process isolation. VMs require a full guest OS, making them heavier and slower to start. |
| **Secrets vs Environment Variables** | Docker Secrets + .env | Secrets are mounted as files (not visible in `docker inspect` or shell history). .env stores non-sensitive configuration. |
| **Docker Network vs Host Network** | Bridge Network    | Isolates container traffic; avoids port conflicts and exposes only necessary ports to the host. |
| **Docker Volumes vs Bind Mounts** | Named Volumes    | Managed by Docker, more portable, and support backup/restore APIs. Bind mounts tie to host paths. |

## Design Decisions

- **Base Image**: Alpine 3.23 (penultimate stable) — smaller footprint than Debian, sufficient for all services.
- **Reverse Proxy**: Two-layer design to showcase both NGINX (traditional, configurable) and Caddy (modern, automatic TLS via HTTPS).
- **TLS**: NGINX enforces TLSv1.2/1.3 only; Caddy handles TLS for bonus subdomains automatically.

## Instructions

See [USER_DOC.md](USER_DOC.md) for end-user instructions (start/stop, access, credentials).
See [DEV_DOC.md](DEV_DOC.md) for developer setup and management.

### Quick Start

```bash
make              # Build images and start all containers
make down         # Stop containers (keeps volumes)
make clean        # Stop containers + remove volumes
make fclean       # Full cleanup (containers, volumes, images)
make re           # Full rebuild
```

## Resources

### Documentation
- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [WordPress Documentation](https://wordpress.org/documentation/)
- [MariaDB Documentation](https://mariadb.org/documentation/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Alpine Linux](https://wiki.alpinelinux.org/)

### AI Usage

Claude wrote detailed study material (e.g., what Docker and the services even are, how they function and can interact). Various models assisted in debugging tasks and specific questions. AI also wrote all documentation (i.e., `*.md` files).
