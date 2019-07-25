FROM alpine:latest
LABEL "project"="www.mf2c-project.eu" "status"="testing" "maintainer"="jens.jensen@stfc.ac.uk"
# This file is for the built in test

# OpenSSL is needed to check (and generate if necessary) credentials;
# so is curl.  In a production environment where credentials are made
# available by the time the script runs, they should not be needed.

RUN apk add --no-cache openvpn openssl curl
ADD vpnclient.sh "/root/vpnclient.sh"
# Alpine doesn't have bash (by default) and the script only needs sh
CMD ["sh", "/root/vpnclient.sh"]
