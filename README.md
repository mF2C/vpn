# VPN server for mF2C


## Establishing credentials for authentication ##

Note that the server and its clients have *distinct* PKIs: the server is using the trusted/infrastructure PKI whereas the clients are using the fog PKI (previously known as "untrust").  Thus, the server needs to trust the client's CA certificate, whereas the client needs to trust the server's.  The server is bootstrapped with credentials directly from the CA, whereas the clients are expected to have certificates through the CA gateway, the CAU, as it will not in general have direct access to the CA.

In a production environment, it is expected that by the time the VPN client is launched, the client certificates are already present (in the /pkidata directory/mount point).  For testing purposes, it is necessary to either depend on the cau-client component, or to call out directly to the CAU.

In addition to the certificates, a shared secret is used.  This secret is generated when the server is configured, and ensures that only authorised (as opposed to authenticated) clients can connect, the idea being that authorised clients have the shared secret shared  with them (the process for doing so needs to be out of band, except for the tests included here.)  In particular, the server generates the secret itself (during bootstrap), so needs to be generated before the clients.

## Upstream ##

The upstream image used here is [OpenVPN](https://hub.docker.com/r/kylemanna/openvpn).  
