FROM alpine:3.23

EXPOSE 80 8443

ARG A_DOMAIN_NAME

RUN apk update && apk add --no-cache caddy nss-tools

COPY conf/Caddyfile.conf /etc/caddy/Caddyfile

COPY tools/ /srv/www

RUN sed -i "s|__DOMAIN_NAME__|${A_DOMAIN_NAME}|g" /etc/caddy/Caddyfile

ENTRYPOINT ["caddy"]

CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
