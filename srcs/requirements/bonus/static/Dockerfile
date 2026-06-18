FROM alpine:3.23

RUN apk update && apk add --no-cache caddy nss-tools

COPY conf/Caddyfile /etc/caddy/Caddyfile

COPY tools/ /srv/www

EXPOSE 8080 443

ENTRYPOINT ["caddy"]

CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
