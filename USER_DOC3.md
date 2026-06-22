# User Documentation — Inception

## What This Stack Provides

A WordPress website with supporting infrastructure, running entirely in Docker containers on a single virtual machine.

### Services

| Service | Purpose | URL |
|---|---|---|
| **NGINX** | Reverse proxy and TLS termination for WordPress | `https://login.42.fr` |
| **WordPress** | CMS running on PHP-FPM (port 9000, internal) | Accessed via NGINX |
| **MariaDB** | Database backend for WordPress (port 3306, internal) | — |
| **Redis** | Object cache for WordPress (port 6379, internal) | — |
| **FTP Server** | File transfer to WordPress volume | `ftp://login.42.fr:21` |
| **Static Website** | HTML/CSS showcase site served by Caddy | `https://static.login.42.fr` |
| **Adminer** | Database management web UI | `https://data.login.42.fr` |
| **Portainer** | Docker container management UI | `https://manage.login.42.fr` |

### Network Access

Only one port is exposed externally: **443** (HTTPS). All other services communicate internally through the Docker bridge network `inception_network`.

FTP uses ports 21 and 21000–21010 (passive mode range).

## Starting and Stopping

From the project root directory:

```bash
# Start the entire stack
make

# Stop all containers (data is preserved)
make down
```

To restart a specific service (e.g., after configuration changes):

```bash
make re nginx
```

## Accessing the Website

1. Ensure `login.42.fr` resolves to your VM's IP address. Add this to `/etc/hosts` on your local machine:
   ```
   <vm_ip>    login.42.fr
   ```

2. Open `https://login.42.fr` in a browser. Accept the self-signed certificate warning.

3. WordPress admin panel: `https://login.42.fr/wp-admin`
   - Username: `supervisor` (set in `srcs/.env` as `WP_ADMIN_USER`)
   - Password: stored in `secrets/wp_admin.txt`

4. A second user exists:
   - Username: `minion` (set in `srcs/.env` as `WP_USER`)
   - Password: stored in `secrets/wp_user.txt`

### Bonus Service URLs

| Service | URL |
|---|---|
| Static Site | `https://static.login.42.fr` |
| Adminer | `https://data.login.42.fr` |
| Portainer | `https://manage.login.42.fr` |

Subdomains must also resolve to the VM's IP. The NGINX stream layer routes by SNI, so the correct subdomain must be used.

## Credential Management

All credentials are stored in the `secrets/` directory as plain text files:

| File | Contains |
|---|---|
| `secrets/mysql.txt` | MariaDB maintenance user password |
| `secrets/wp_db.txt` | WordPress database user password |
| `secrets/wp_admin.txt` | WordPress admin user password |
| `secrets/wp_user.txt` | WordPress regular user password |
| `secrets/ftp.txt` | FTP user password |
| `secrets/portainer.txt` | Portainer admin password |

Non-sensitive configuration lives in `srcs/.env` (domain name, WordPress settings, FTP passive IP).

**Do not commit secrets to git.** The `secrets/` directory should be in `.gitignore`.

## Verifying Services Are Running

### Check container status

```bash
make ps
```

All containers should show `Up` status. If a container shows `Restarting`, check its logs:

```bash
make sh nginx    # shell into a specific container
make logs        # follow logs from all containers
```

### Verify individual services

| Check | Command / Method |
|---|---|
| WordPress loads | Open `https://login.42.fr` |
| MariaDB responds | `make sh mariadb` → `mariadb -e "SELECT 1"` |
| Redis responds | `make sh redis` → `redis-cli ping` (returns `PONG`) |
| FTP accepts connections | `ftp login.42.fr` from host |
| Static site loads | Open `https://static.login.42.fr` |
| Adminer loads | Open `https://data.login.42.fr` |
| Portainer loads | Open `https://manage.login.42.fr` |

### Container restart policy

All containers use `restart: always`. If a container crashes, Docker automatically restarts it. No manual intervention is needed.
