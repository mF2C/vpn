# VPN server for mF2C

Based on Kyle Manna's OpenVPN image, it uses the mF2C PKIs to
authenticate the server and clients.  Note that the server's and the
clients' PKIs are different; the former uses the infrastructure PKI
(aka "it2trustedca") and the latter the Fog CA (aka
"it2untrustedca").

# OpenVPN image

The container is based directly on the upstream OpenVPN image.  It is
recommended to stick the configuration into a separate volume, mounted
on /etc/openvpn by default, although it would work without it.

Note that we use the upstream image unmodified; merely adding a
configuration script to it which is tailored to bootstrapping the
project's PKI.  This script (or its actions) is described in the
following sections.

# Configuration

Most of the configuration data is located in the `openvpn` directory,
and only two configuration steps are needed - it is not necessary to
use the upstream configuration scripts.

It would make sense to copy this data to a persistent volume.  In this
case, the configuration should be mounted on `/etc/openvpn` (i.e., the
full path of the `openvpn.conf` file will be
`/etc/openvpn/openvpn.conf`).

The PKI is currently distributed with the code, since there is no
other trust anchor distribution mechanism.  The default location is
`/etc/openvpn/pki`, but see also the description of environment
variables below.

The configuration script below may be done by the administrator when
(or prior to) building the container, e.g. by mounting the
configuration from an external volume into the container.  If not
done, the server setup script will attempt to do these steps itself.

## 1. Obtain server credentials (REQUIRED)

This step can be done manually, or will be attempted by the setup
script.

The certificate/key should be obtained from the infrastructure
("trusted") CA, and placed in `/etc/openvpn/pki/servercert.pem` and
`serverkey.pem` respectively.

The server's setup script will attempt to fetch credentials from an
endpoint made available to the script through the `TRUSTCA` or
`TRUSTEDCA` environment variable if credentials are missing.

## 2. Obtain DH parameters (REQUIRED)

This step can be done manually, or will be attempted by the setup
script.  It is quite simple; although they are not terribly secret,
it's probably best to generate the Diffie-Hellman parameters afresh
for each new install.

`openssl dhparam -out /etc/openvpn/pki/dh.pem 2048`

This step will take a bit of time to run (minutes).  The step can be
skipped if DH is not used; however, the server then falls back to ECDH
which needs to be configured.  Note the output location of the file.

# Build and run the container

In a simple form, the following should build and run the container.
We assume the volume with the configuration data is called
`ovpn-data-mf2c` as recommended by the upstream porovider.

```
docker run -v ovpn-data-mf2c:/etc/openvpn -p 1194:1194/udp --name vpnserver --cap-add=NET_ADMIN kylemanna/openvpn:latest
```

Alternatively, one can use the docker-compose file available in the
parent directory.  Note that it will build a simple client and connect
it to the server.

Since we are using Kyle Manna's image, it should be sufficient to run
`ovpn_run`.  This is the default action in the image.

# Discovery

By default, the server should be discoverable to the client as
`vpnserver`.

# Checking status

All being well, the file (in the container) `/tmp/ovpn-status.log`
should be present and show basic status of the clients connected to
it.  Note that the log is rewritten from time to time, so once a
client connects, it might take a minute before the file is next
updated.

# Environment Variables #

| Variable | Required? | Description | Default |
| :--- | :---: | :--- | :--- |
| VPNSERVER_CONFIGDIR | no | Configuration | `/etc/openvpn` |
| VPNSERVER_TRUSTANCHORS | no | Trust anchors (CA certs) | `${VPNSERVER_CONFIGDIR}/pki` |
| CN | no | CommonName of server/host | hostname; then `vpnserver` |
| TRUSTCA | yes, unless credentials are already available | Endpoint for infrastructure CA |
| TRUSTEDCA | see TRUSTCA | Alternative name for TRUSTCA | N/A |
