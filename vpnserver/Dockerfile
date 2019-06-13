FROM kylemanna/openvpn
LABEL "project"="mf2c-project.eu" "status"="production" "maintainer"="jens.jensen@stfc.ac.uk"
ENV "OVPN_DATA"="vpn_vpnconfig"
EXPOSE 1194/udp
RUN apk add --no-cache curl
RUN mkdir -p /etc/openvpn
ADD vpnserver.sh /root/vpnserver.sh
ADD openvpn /etc/openvpn
VOLUME /etc/openvpn
CMD ["bash", "/root/vpnserver.sh"]
