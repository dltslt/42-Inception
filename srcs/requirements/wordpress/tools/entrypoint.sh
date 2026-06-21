#!/bin/sh
set -e

MYSQL_PASSWORD=$(cat /run/secrets/mysql)
WP_DB_PASSWORD=$(cat /run/secrets/wp_db)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user)

# ── 1. Wait for MariaDB ─────────────────────────────────────────────────────
# MariaDB may still be initialising when this container starts.
# We try to connect in a loop until it responds.
echo "Waiting for MariaDB..."
# until mysqladmin ping -h mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; do
until mariadb -h inception_mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; do
    echo "MariaDB not ready yet, retrying in 2s..."
    sleep 2
done
echo "MariaDB is ready."

# ── 2. Check if WordPress is already installed ───────────────────────────────
# wp-config.php existing is our signal that setup has already run.
if [ ! -f "${WP_PATH}/wp-config.php" ]; then

    echo "First run — setting up WordPress..."
	# create the wp database user
	mariadb -h inception_mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "
CREATE DATABASE IF NOT EXISTS ${WP_DB} CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER IF NOT EXISTS '${WP_DB_USER}' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES
  ON ${WP_DB}.* TO '${WP_DB_USER}'@'%';
	"
	echo "Database user for WordPress created."
	sleep 1
    # Generate wp-config.php with DB credentials from environment variables
    wp config create \
        --path="${WP_PATH}" \
        --dbname="${WP_DB}" \
        --dbuser="${WP_DB_USER}" \
        --dbpass="${WP_DB_PASSWORD}" \
        --dbhost=inception_mariadb
	
    # Run the WordPress database installation
    wp core install \
        --path="${WP_PATH}" \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email

    # Create the second (non-admin) user required by the subject
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --path="${WP_PATH}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}"

	#chown www-data:www-data /var/www/html/wp-config.php
    echo "WordPress installation complete."
else
    echo "WordPress already installed, skipping setup."
fi

# replace script with php-fpm
# -F: run in foreground
# -R: allow running as root
exec php-fpm83 -F
