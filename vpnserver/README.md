# VPN server for mF2C

Based on Kyle Manna's OpenVPN image, it uses the mF2C PKIs to
authenticate the server and clients.  Note that the server's and the
clients' PKIs are different; the former uses the infrastructure PKI
(aka "it2trustedca") and the latter the Fog CA (aka
"it2untrustedca").

# OpenVPN image

The container is based directly on the upstream OpenVPN image.  It is
recommended to stick the configuration into a separate volume,
although it would work without it.

# Configuration

Most of the configuration data is located in the `openvpn` directory,
and only two manual steps are needed - it is not necessary to use the
upstream configuration at all.

It would make sense to copy this data to a persistent volume.  In any
case, the configuration should be mounted on `/etc/openvpn` (i.e., the
full path of the `openvpn.conf` file will be
`/etc/openvpn/openvpn.conf`).

The PKI is currently distributed with the code, since there is no
other trust anchor distribution mechanism.

## 1. Obtain server credentials

The certificate/key should be obtained from the infrastructure
("trusted") CA, and placed in `/etc/openvpn/pki/servercert.pem` and
`serverkey.pem` respectively.  This manual step is REQUIRED.

## 2. Obtain DH parameters

This step is quite simple; although they are not terribly secret, it's
probably best to generate them afresh for each install.

`openssl dhparam -out /etc/openvpn/pki/dh.pem 2048`

This step will take a bit of time to run (minutes).  The step can be
skipped if DH is not used; however, the server then falls back to ECDH
which needs to be configured.  Note the output location of the file.

# 

Since we are using Kyle Manna's image, it should be sufficient to run
`ovpn_run`.

# Build and run the container

In a simple form, the following should build and run the container.
We assume the volume with the configuration data is called
`ovpn-data-mf2c` as recommended by the upstream porovider.

```
docker run -v ovpn-data-mf2c:/etc/openvpn -p 1194:1194/udp --cap-add=NET_ADMIN kylemanna/openvpn:latest
```

# Checking status

All being well, the file (in the container) `/tmp/ovpn-status.log`
should be present and show basic status of the clients connected to
it.  Note that the log is rewritten from time to time, so once a
client connects, it might take a minute before the file is next
updated.
