FROM alpine:3.23

RUN apk update && apk add --no-cache caddy

COPY conf/Caddyfile /etc/caddy/Caddyfile

COPY tools/ /srv/www

EXPOSE 8080

ENTRYPOINT ["caddy"]

CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
