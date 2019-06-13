# mF2C VPN client #

The client script is intended to launch a VPN client in a container
built with OpenVPN.  The Dockerfile presented here is merely for
building a test client.


# Using the Script to Launch the Client #

Currently the script is designed to run and exit with a non-zero
return code if something went wrong; and exit with a zero return code
if successful.

## Exiting ##

The exit code for the script are as follows:

0. Success; the VPN client was started (but see below)
1. Network device error, probably a permissions problem
2. Credentials error; perhaps the pkidata was not set up correctly
   prior to running the script.
3. VPN client configuration error, again possibly a permissions
   problem.
4. (Currently unused.)
5. (Currently unused) Failure to launch VPN client

The environment variable VPN_DAEMON controls whether to launch the VPN client
as a daemon or not.  If set and the value is `TRUE`, the client is
launched as a daemon and the script exits with status 0 (provided the
client launched OK.)  If the value is `FALSE`, the script runs as long
as the VPN client is running, so basically the script does not exit.
The latter is useful for testing.

# Building Containers #

The test client illustrates the basics of building a client image.
When it comes to building containers, the following steps should be
followed:

## 1. Network capabilities ##

To build a container, you will need `--cap-add=NET_ADMIN` as the
client will need to set up a network device (viz., the VPN network.)

## 2. Client Credentials ##

The current implemetnation assumes that client credentials have been
generated and stored in /pkidata (which is presumably a mountpoint for
a volume), where, for some reason, the client certificate and key are
called server.crt and server.key, respectively.  The private key
cannot be encrypted.

The container should thus mount the volume with the client credentials
on /pkidata.  Since we use these keys, there are no secrets in the
script, nor in the `.ovpn` file.  The `.ovpn` file, in fact, currently
has the hardwired certificate of the CA that issues the server's
credentials.

## 3. VPN server location ##

The `vpnserver` is meant to resolve to the location of the VPN server;
conventionally, the link is provided with `--link` when starting the
client, or configured in the `docker-compose.yml` file.


# Environment #

The script makes use of the following environment variables:

| Variable      | Required? | Description | Default |
| :--- | :---: | :--- | :--- |
| VPNSERVER     | no		| Location of VPN server | vpnserver |
| CN   	   	   	| no |commonName for a host certificate request | hostname |
| CAU_URL | no | CAU endpoint | no default |
| VPN_DAEMON | no | Whether to run the client as a Daemon | "TRUE" |
| PKIDATA | no | Location/mountpoint of client credentials | /pkidata |
| CA_ENDPOINT | no | Endpoint for (fog) CA | no default |

Note that the CAU_URL and CA_ENDPOINT are needed only if the client
credentials are not present by the time the script runs.  The client
will then attempt to create a Certificate Signing Request (CSR) and
submit it first to the CAU at the CAU_URL (which despite the name is
not a URL, it's a host address and port, as in "127.0.0.1:40000").  If
that fails, it will try to contact the CA directly, POSTing the CSR to
the endpoint provided.

Since this is the client, the certificate it uses should be signed by
the Fog CA (aka "untrust" or "untrusted").
