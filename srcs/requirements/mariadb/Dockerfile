FROM alpine:3.23

EXPOSE 3306

RUN apk update && apk add --no-cache mariadb mariadb-client

RUN mkdir -p /run/mysqld && \
	chown -R mysql:mysql /run/mysqld && \
	chown -R mysql:mysql /var/lib/mysql

RUN mariadb-install-db --user=mysql --datadir=/var/lib/mysql && \
	mv /etc/my.cnf.d/mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf.bak

COPY ./conf/maria.cnf /etc/my.cnf.d/mariadb-server.cnf

COPY tools/entrypoint.sh /run/entrypoint.sh

ENTRYPOINT [ "sh" ]

CMD ["/run/entrypoint.sh"]
