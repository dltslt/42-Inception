FROM alpine:3.23

RUN apk update && apk add --no-cache php83 php83-fpm

ENTRYPOINT ["php-fpm83"]

CMD ["-F", "-R"]