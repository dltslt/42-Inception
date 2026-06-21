FROM alpine:3.23

EXPOSE 8080

RUN apk update && apk add --no-cache \
	php83 \
	php83-mysqli \
	php83-session \
	php83-pdo \
	php83-pdo_mysql \
	wget

RUN mkdir -p /var/www/adminer && \
	wget -q -O /var/www/adminer/adminer.php https://www.adminer.org/latest.php

COPY ./conf/index.php /var/www/adminer/index.php

COPY ./tools/entrypoint.sh /run/entrypoint.sh

RUN chmod +x /run/entrypoint.sh

ENTRYPOINT [ "/run/entrypoint.sh" ]
