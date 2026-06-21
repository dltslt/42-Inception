FROM alpine:3.23

EXPOSE 9000

# Install ca-certificates for HTTPS downloads, and wget for the binary
RUN apk update && apk add --no-cache wget

# check https://github.com/portainer/portainer/releases/latest
ARG PORTAINER_VERSION=2.39.3

RUN wget -q -O /tmp/portainer.tar.gz \
	"https://github.com/portainer/portainer/releases/download/${PORTAINER_VERSION}/portainer-${PORTAINER_VERSION}-linux-amd64.tar.gz" \
	&& tar -xzf /tmp/portainer.tar.gz -C /tmp/ \
	&& mv /tmp/portainer/portainer /portainer \
	&& mv /tmp/portainer/public /public \
	&& rm -rf /tmp/portainer.tar.gz /tmp/portainer

RUN mkdir -p /data

ENTRYPOINT [ "/portainer" ]

CMD [ "--data=/data", "--admin-password-file=/run/secrets/portainer" ]
