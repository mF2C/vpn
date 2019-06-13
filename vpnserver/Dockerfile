FROM kylemanna/openvpn
LABEL "project"="mf2c-project.eu" "status"="production" "maintainer"="jens.jensen@stfc.ac.uk"
ENV "OVPN_DATA"="mf2c-vpn_vpnconfig"
EXPOSE 1194/udp
RUN apk add --no-cache curl
VOLUME mf2c-vpn_pkidata
VOLUME mf2c-vpn_vpnconfig
ADD vpnserver.sh /root/vpnserver.sh
ADD openvpn /etc/openvpn
CMD ["bash", "/root/vpnserver.sh"]
