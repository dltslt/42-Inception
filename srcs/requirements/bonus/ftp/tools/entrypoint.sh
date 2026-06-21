#!/bin/sh
set -e

FTP_PASSWORD=$(cat /run/secrets/ftp)

if ! id "${FTP_USER}" > /dev/null 2>&1; then
	echo "Creating user: ${FTP_USER}"

	# 1. create FTP user 
	# home directory shall point to wordpress
	#   -h: home directory
	#   -s: login shell
	#   -D: no password set, skips the prompt
	#   -u: explicit UID >= 2000 (required by --minuid)
	# adduser -h /var/www/html -s /sbin/nologin -D -u 2000 "${FTP_USER}"
	printf '%s\n%s\n' "$FTP_PASSWORD" "$FTP_PASSWORD" | \
		pure-pw useradd ${FTP_USER} -u www-data -d "${WP_PATH}"
	pure-pw mkdb
	# set the password
	# echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd

	echo "User created."
fi

echo "Starting Pure-FTPd..."
# --forcepassiveip essential for connection
# exec sleep infinity
#| Long option          | Short option       | Your value                                 |
#| -------------------- | ------------------ | ------------------------------------------ |
#| `--bind`             | `-S`               | `0.0.0.0,21`                               |
#| `--passiveportrange` | `-p`               | `21000:21010`                              |
#| `--forcepassiveip`   | `-P`               | `"${FTP_PASSIVE_IP}"`                      |
#| `--noanonymous`      | `-E`               | (flag only)                                |
#| `--createhomedir`    | `-j`               | (flag only)                                |
#| `--minuid`           | `-I`               | `2000`                                     |
#| `--umask`            | `-U`               | `133:022`                                  |
#| `--nochmod`          | `-R`               | (flag only)                                |
#| `--nodaemon`         | *none* (see below) |                                            |
#| `--logfile`          | `-O`               | logging option, but syntax varies by build |

exec pure-ftpd \
	-l puredb:/etc/pureftpd.pdb \
	-S 0.0.0.0,21 \
	-p 21000:21010 \
	-P "${FTP_PASSIVE_IP}" \
	-E \
	-I 82 \
	-U 133:022 \
	-R
