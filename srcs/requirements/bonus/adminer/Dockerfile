FROM alpine:3.23

EXPOSE 8081

RUN apk update && apk add --no-cache \
	php83 \
	php83-mysqli \
	php83-session \
	php83-pdo \
	php83-pdo_mysql \
	wget

RUN mkdir -p /var/www/adminer

RUN wget -q -O /var/www/adminer/index.php https://www.adminer.org/latest.php

ENTRYPOINT [ "php83" ]

CMD ["-S", "0.0.0.0:8081", "-t", "/var/www/adminer/"]
