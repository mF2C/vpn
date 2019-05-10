FROM alpine
LABEL "project"="mf2c-project.eu" "maintainer"="jens.jensen@stfc.ac.uk"
VOLUME ["/pkidata"]
RUN apk add --no-cache openvpn
ADD ./vpnclient.sh /root/vpnclient.sh
ENV VPN_DAEMON=FALSE
CMD ["sh","/root/vpnclient.sh"]
