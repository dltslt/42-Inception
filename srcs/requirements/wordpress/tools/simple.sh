#!/bin/sh
set -e

MYSQL_PASSWORD=$(cat /run/secrets/mysql_pwd)

# ── 2. Check if WordPress is already installed ───────────────────────────────
# wp-config.php existing is our signal that setup has already run.
if [ ! -f "${WP_PATH}/wp-config.php" ]; then
    echo "[wordpress] First run — setting up WordPress..."

    # Generate wp-config.php with DB credentials from environment variables
    wp config create \
        --path="${WP_PATH}" \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost=mariadb \
        --allow-root

    echo "[wordpress] WordPress config creation complete."
else
    echo "[wordpress] WordPress already installed, skipping setup."
fi

# start php as pid 1, replace the script
# -F: run in foreground (do not daemonise)
# -R: allow running as root
exec php-fpm83 -F -R
