FROM alpine:3.23

RUN apk update && apk add --no-cache pure-ftpd

COPY tools/entrypoint.sh /run/entrypoint.sh

RUN adduser -u 82 -D -S -G www-data www-data

RUN chmod +x /run/entrypoint.sh

EXPOSE 21 21000-21010

ENTRYPOINT ["/run/entrypoint.sh"]
