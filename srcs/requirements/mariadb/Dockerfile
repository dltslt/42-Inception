FROM alpine:3.23

RUN apk update && apk add --no-cache mariadb

COPY ./tools/setup.sql /tmp/setup.sql

RUN mkdir -p /run/mysqld && \
	chown -R mysql:mysql /run/mysqld && \
	chown -R mysql:mysql /var/lib/mysql

RUN mariadb-install-db --user=mysql --datadir=/var/lib/mysql && \
	mariadbd --user=mysql --bootstrap < /tmp/setup.sql && \
	rm -f /tmp/setup.sql

ENTRYPOINT [ "mariadbd" ]

CMD ["--user=mysql"]
