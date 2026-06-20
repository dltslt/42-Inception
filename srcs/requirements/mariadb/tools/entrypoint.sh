#!/bin/sh
set -e

if [ ! -f /var/lib/mysql/.init_completed ]; then
	echo "Securing MariaDB..."

	# Start a temporary server, no networking
	# --socket=/run/mysqld/mysqld.sock
	mariadbd --user=mysql --skip-networking &
	tmp_pid=$!

	# Wait for it to be ready
	until mariadb -e "SELECT 1" >/dev/null 2>&1; do
	sleep 1
	done

#	manual implementation of `mariadb-secure-installation`
	MYSQL_SECURE="
-- Enable unix_socket authentication
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Disallow remote root login -- works
DELETE FROM mysql.user WHERE User='root' 
AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database -- both work
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Reload privilege tables
FLUSH PRIVILEGES;
"

# creating a user for other containers to attend to their own needs
	MYSQL_MAINTAIN_PWD=$(cat /run/secrets/mysql_pwd)
	echo "new password: ${MYSQL_MAINTAIN_PWD}"
	MYSQL_MAINTAIN="
-- create a user <boss> with a password
CREATE USER 'boss'@'%' IDENTIFIED BY '${MYSQL_MAINTAIN_PWD}';

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, ALTER
  ON *.* TO 'boss'@'%' WITH GRANT OPTION;

GRANT CREATE USER ON *.* TO 'boss'@'%';

FLUSH PRIVILEGES;
"
	# execute commands
	mariadb -e "${MYSQL_SECURE}"
	mariadb -e "${MYSQL_MAINTAIN}"
	# shutdown temporary server
	mariadb-admin shutdown
	# wait for the shutdown to be completed
	wait "$tmp_pid"

	touch /var/lib/mysql/.init_completed
	echo "MariaDB Initialization complete."
fi

exec mariadbd --user=mysql