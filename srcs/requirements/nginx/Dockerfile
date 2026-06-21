FROM alpine:3.23

EXPOSE 443

ARG A_DOMAIN_NAME
ARG A_WP_PATH

RUN apk update && apk add --no-cache nginx nginx-mod-stream openssl

RUN mkdir -p /etc/nginx/ssl/ && \
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/nginx/ssl/nginx.key \
	-out /etc/nginx/ssl/nginx.crt \
	-subj "/C=AT/ST=IDF/L=Vienna/O=42/CN=${A_DOMAIN_NAME}"

COPY conf/nginx.conf /etc/nginx/http.d/${A_DOMAIN_NAME}.conf

COPY conf/forward.conf /etc/nginx/stream.d/forward.conf

COPY conf/log.conf /etc/nginx/stream.d/log.conf

RUN sed -i "s|__DOMAIN_NAME__|${A_DOMAIN_NAME}|g" \
    	/etc/nginx/http.d/${A_DOMAIN_NAME}.conf && \
	sed -i "s|__WP_PATH__|${A_WP_PATH}|g" \
    	/etc/nginx/http.d/${A_DOMAIN_NAME}.conf && \
	sed -i "s|__DOMAIN_NAME__|${A_DOMAIN_NAME}|g" \
		/etc/nginx/stream.d/forward.conf && \
	rm -rf /etc/nginx/http.d/default.conf

ENTRYPOINT [ "nginx" ]

CMD [ "-g", "daemon off;" ]
