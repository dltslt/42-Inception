FROM alpine:3.23

RUN apk update && apk add --no-cache nginx openssl

ARG DOMAIN_NAME=$DOMAIN_NAME
ARG WP_PATH=$WP_PATH

RUN mkdir -p /etc/nginx/ssl/ && \
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/nginx/ssl/nginx.key \
	-out /etc/nginx/ssl/nginx.crt \
	-subj "/C=AT/ST=IDF/L=Vienna/O=42/CN=${DOMAIN_NAME}"

EXPOSE 80 443

COPY conf/nginx.conf /etc/nginx/http.d/DOMAIN_NAME.conf

RUN sed -i "s|__DOMAIN_NAME__|${DOMAIN_NAME}|g" \
    /etc/nginx/http.d/DOMAIN_NAME.conf && \
	sed -i "s|__WP_PATH__|${WP_PATH}|g" \
    /etc/nginx/http.d/DOMAIN_NAME.conf

ENTRYPOINT [ "nginx" ]

CMD [ "-g", "daemon off;" ]