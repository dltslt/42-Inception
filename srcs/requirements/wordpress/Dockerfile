FROM alpine:3.23

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
	&& ln -s /usr/bin/php83 /usr/bin/php \
	&& sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php83/php.ini

RUN curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x wp-cli.phar \
	&& mv wp-cli.phar /usr/local/bin/wp

ARG DOMAIN_NAME=$DOMAIN_NAME
ARG WP_PATH=$WP_PATH

RUN which php || true
RUN which php83 || true
RUN php --version || true
RUN php83 --version || true
RUN grep -n "memory_limit" /etc/php83/php-fpm.d/www.conf || true

RUN mkdir -p ${WP_PATH} && wp core download --path="${WP_PATH}" --locale=en_US --allow-root

COPY ./tools/simple.sh /simple.sh

ENTRYPOINT ["/simple.sh"]
