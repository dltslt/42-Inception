# User Documentation — Inception

This document covers everything an end user or administrator needs to run the stack day-to-day: what it provides, how to start/stop it, how to log in to each service, how to manage credentials, and how to confirm everything is healthy.

For the architecture diagram, design rationale, and technology comparisons, see [README.md](README.md). For internal setup, the Makefile/Compose internals, and data persistence details, see [DEV_DOC.md](DEV_DOC.md).

## What This Stack Provides

| Service | Role | URL | Notes |
|---|---|---|---|
| **WordPress** | The main website (CMS) | `https://mweghofe.42.fr` | Served through NGINX, backed by MariaDB |
| **NGINX** | TLS entry point for the whole infrastructure | port 443 | Not a "service" you visit directly — routes everything |
| **MariaDB** | Database for WordPress | internal only | No exposed port, reached only by other containers |
| **Redis** | Object cache for WordPress | internal only | Speeds up WordPress page/DB queries |
| **Static website** | Showcase site served by Caddy (bonus) | `https://static.mweghofe.42.fr` | Plain HTML/CSS |
| **Adminer** | Web UI for MariaDB (bonus) | `https://data.mweghofe.42.fr` | Login pre-filled, see below |
| **Portainer** | Web UI to manage the Docker containers (bonus) | `https://manage.mweghofe.42.fr` | Full Docker control, use with care |
| **FTP (Pure-FTPd)** | File access to the WordPress volume (bonus) | `ftp://mweghofe.42.fr` (port 21) | Same files WordPress serves |

Everything except FTP is reached over HTTPS on port 443: NGINX inspects the requested hostname (via SNI) and forwards the bare domain to WordPress, and any subdomain to Caddy, which then serves/proxies the right bonus service. See [README.md § Architecture](README.md#architecture) for the diagram.

## Starting and Stopping

Run all commands from the project root.

```bash
make          # build every image (if needed) and start the whole stack, detached
```

The first run takes longer, since every image is built and WordPress/MariaDB run their one-time setup (WordPress install, database creation, etc.).

```bash
make down     # stop and remove containers + network — your data is kept
```

```bash
make clean    # like `down`, but also deletes the volumes' data on disk
make fclean   # like `clean`, but also removes the built images and build cache
```

> `make clean`/`make fclean` are destructive — your WordPress site and database are wiped. Use `make down` for a normal stop.

To rebuild everything from a clean slate:

```bash
make re       # equivalent to: remove everything, then `make`
```

## Accessing the Website and Admin Panel

1. Make sure `mweghofe.42.fr` (and its subdomains) resolve to the host running the stack — on your own machine, add a line to `/etc/hosts`:
   ```
   <vm_ip>    mweghofe.42.fr static.mweghofe.42.fr data.mweghofe.42.fr manage.mweghofe.42.fr
   ```
2. Open `https://mweghofe.42.fr` in a browser. The certificate is self-signed, so accept the browser's warning.
3. The WordPress admin panel is at `https://mweghofe.42.fr/wp-admin`:
   - **Administrator**: username from `WP_ADMIN_USER` in `srcs/.env` (defaults to `supervisor`), password in `secrets/wp_admin.txt`.
   - **Regular user** (author role): username from `WP_USER` in `srcs/.env` (defaults to `minion`), password in `secrets/wp_user.txt`.

### Bonus services

| Service | URL | Login |
|---|---|---|
| Static website | `https://static.mweghofe.42.fr` | none, public |
| Adminer | `https://data.mweghofe.42.fr` | System: MySQL; Server/username are pre-filled (`inception_mariadb` / `boss`); password in `secrets/mysql.txt` |
| Portainer | `https://manage.mweghofe.42.fr` | Username `admin`; password in `secrets/portainer.txt` (this is the password you put in that file on first setup) |
| FTP | `ftp://mweghofe.42.fr` (port 21, passive range 21000-21010) | Username from `FTP_USER` in `srcs/.env` (defaults to `ftpu`), password in `secrets/ftp.txt`. Root directory is the same volume WordPress serves. |

## Creating and Managing Credentials

No password ever lives in a Dockerfile, `docker-compose.yml`, or `.env` — every credential is a [Docker secret](https://docs.docker.com/engine/swarm/secrets/): a plain-text file under `secrets/`, mounted read-only inside the one container that needs it, at `/run/secrets/<name>`.

### Creating the secrets

On a fresh clone, `secrets/` is empty (its contents are gitignored) — you need to create six files before `make` will work. Each file contains **one line: just the password** (the corresponding username lives in `srcs/.env`, see below).

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

| File | Used by | Controls the password for |
|---|---|---|
| `secrets/mysql.txt` | MariaDB, WordPress, Adminer | `boss`, the MariaDB maintenance user (created during MariaDB's first boot) |
| `secrets/wp_db.txt` | WordPress | the WordPress database user (`WP_DB_USER` in `.env`) |
| `secrets/wp_admin.txt` | WordPress | the WordPress administrator (`WP_ADMIN_USER` in `.env`) |
| `secrets/wp_user.txt` | WordPress | the second, non-admin WordPress user (`WP_USER` in `.env`) |
| `secrets/ftp.txt` | FTP | the FTP user (`FTP_USER` in `.env`) |
| `secrets/portainer.txt` | Portainer | the Portainer `admin` account |

> The subject requires the WordPress administrator's username to **not** contain `admin`/`administrator` in any casing. The default (`supervisor`) already satisfies this — if you change `WP_ADMIN_USER` in `.env`, keep that rule in mind.

### Non-secret configuration

Everything that isn't a credential (domain name, usernames, WordPress site title, FTP passive-mode IP, ...) lives in `srcs/.env`. It's safe to version-control since it holds no passwords. See [DEV_DOC.md § Environment Setup](DEV_DOC.md#environment-setup-from-scratch) for the full list of variables.

### Changing credentials later

1. Edit the relevant file in `secrets/` (and/or the matching username in `srcs/.env`).
2. Recreate the affected container(s) so they pick up the new secret:
   ```bash
   make re <service>     # e.g. make re wordpress
   ```
   Note: WordPress and MariaDB only *use* the secret to create the corresponding user on their very first boot (detected via a sentinel file/flag). Changing the secret after that point changes what's mounted into the container, but you'll also need to update the password inside WordPress/MariaDB itself (e.g. via `wp user update` or Adminer) for the two to match again.

Never commit `secrets/` to git — it's listed in `.gitignore`.

## Verifying Services Are Running

```bash
make ps       # list every container and its status
```

All containers should show `Up`. Containers use `restart: always`, so a crash is automatically recovered without any manual action — if a container is stuck restarting, check its logs.

```bash
make logs             # follow logs from every container
make sh <service>     # open a shell inside a running container, e.g. `make sh nginx`
```

### Per-service checks

| Check | How |
|---|---|
| WordPress | Open `https://mweghofe.42.fr` — the site should load |
| MariaDB | `make sh mariadb` then `mariadb -e "SELECT 1"` |
| Redis | `make sh redis` then `redis-cli ping` → expect `PONG` |
| Static website | Open `https://static.mweghofe.42.fr` |
| Adminer | Open `https://data.mweghofe.42.fr` — should show the login form |
| Portainer | Open `https://manage.mweghofe.42.fr` — should show the login form |
| FTP | `ftp mweghofe.42.fr` from the host, log in with `secrets/ftp.txt` |

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `make` fails while building | Run `make debug` for full build output and locate the failing step |
| A container keeps restarting | `make logs` (or `docker logs <container>`) to see why it's exiting |
| "Database Connection Error" on WordPress | MariaDB isn't ready yet, or `secrets/wp_db.txt` doesn't match what was used when the database user was first created |
| Browser shows a certificate warning | Expected — all TLS certificates in this project are self-signed |
| Subdomain (`static.`/`data.`/`manage.`) returns nothing / times out | Make sure the subdomain resolves to the VM's IP too, not just the bare domain |
| FTP connection refused | Check `make logs` for the ftp container, and that ports 21 and 21000-21010 are reachable |

For a deeper look at how each service starts up internally (useful when the symptom isn't covered above), see [DEV_DOC.md § Service Architecture](DEV_DOC.md#service-architecture) and [DEV_DOC.md § Troubleshooting](DEV_DOC.md#troubleshooting).
