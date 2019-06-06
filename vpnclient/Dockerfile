FROM alpine:latest
LABEL "project"="www.mf2c-project.eu" "status"="unit-test" "maintainer"="jens.jensen@stfc.ac.uk"

# OpenSSL is needed to check (and generate if necessary) credentials;
# so is curl.  In a production environment where credentials are made
# available by the time the script runs, they should not be needed.

RUN apk add --no-cache openvpn openssl curl
ADD vpnclient.sh "/root/vpnclient.sh"
# Alpine doesn't have bash and the script only needs sh
CMD ["sh", "/root/vpnclient.sh"]
