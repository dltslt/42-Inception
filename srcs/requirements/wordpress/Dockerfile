FROM alpine:3.23

EXPOSE 9000

ARG DOMAIN_NAME=$DOMAIN_NAME
ARG WP_PATH=$WP_PATH

RUN apk update && apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-phar \
    php83-curl \
    php83-gd \
    php83-mbstring \
    php83-xml \
    php83-dom \
    php83-exif \
    php83-fileinfo \
    php83-json \
    php83-openssl \
    php83-zip \
    php83-opcache \
    php83-session \
    php83-iconv \
    php83-tokenizer \
    php83-simplexml \
    curl \
	mariadb-client \
	&& ln -s /usr/bin/php83 /usr/bin/php \
	&& sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php83/php.ini

RUN curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x wp-cli.phar \
	&& mv wp-cli.phar /usr/local/bin/wp

RUN mkdir -p ${WP_PATH} && \
	adduser -u 82 -D -S -G www-data www-data && \
	chown -R www-data:www-data /var/www/html && \
	chmod -R 755 /var/www/html && \
	chown -R www-data:www-data /var/log/php83

USER www-data

RUN wp core download --path="${WP_PATH}" --locale=en_US

COPY ./conf/php-fpm.conf /etc/php83/php-fpm.d/www.conf

COPY ./tools/entrypoint.sh /run/entrypoint.sh

# RUN chmod +x /run/entrypoint.sh

ENTRYPOINT ["sh"]

CMD ["/run/entrypoint.sh"]
