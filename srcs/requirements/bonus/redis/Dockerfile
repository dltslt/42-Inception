FROM alpine:3.23

RUN apk update && apk add --no-cache redis

COPY conf/redis.conf /etc/redis.conf

# not needed if persistence is off
RUN mkdir -p /data && chown redis:redis /data

EXPOSE 6379

ENTRYPOINT [ "redis-server" ]

CMD ["/etc/redis.conf"]
