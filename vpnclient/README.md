# mF2C VPN client #

The client script is intended to launch a VPN client in a container
built with OpenVPN.  The Dockerfile presented here is merely for
building a test client.


# Using the Script to Launch the Client #

The script runs and launches a VPN client, connecting to an already
running server.  If run in production mode, it assumes a full mF2C
environment (see below).  It also has a unit test mode, where it can
bypass the standard mF2C agent flows and test itself.  Note that the
default is production mode.

If the container is run in host mode, the VPN network is exported to
the host, but will **not update the host's routing table**.  This
means that only packets addressed to a VPN address will route over the
VPN.  Compare this to (say) a home user or corporate laptop
environment where the VPN routes *every* packet through the VPN
server.

Note that in host mode, the port for the API cannot be remapped.

If not run in host mode, the VPN will by default be available only
inside the container.  This is useful for testing.

The script will continue to run in case of failure, but the API will
indicate the failure and the details of the failure, as described
below.  The script only fails if it cannot launch the API.

Status is also (optionally) written to a file location, which can be
useful for other components which have not got access to the network.

## Exiting ##

The exit code for the script are as follows:

1. Error launching API (cannot provide status information)

If successful, or there are failures after launching the API (see
status messages below), the container keeps running, continuously
updating (and timestamping) its status messages.

## API ##

As of version 1.1.1, there is an API.  It supports a HTTP GET request
to `/api/get_vpn_ip` on port 1999 (by default).

What is returned is a JSON structure of the form

```
{
   "ip" : "192.168.255.2",
   "status" : "connected",
   "stats" : {
       "total" : "3",
       "good" : "3",
       "error" : "0",
       "noconn" : "0"
    },
    "server" : "192.168.255.1",
    "lastUpdate" : "20190927 09:46:07+0000",
    "msg": ""
}
					  
```

The `ip` value is the IP address of the VPN client on the VPN network;
it is empty until the client is connected (most of the others are
empty, too, as they have no meaning till the connection is
established).  The `server` value is the IP address of the server on
the VPN network.

The following status codes can be expected (in approximately this
order):

* `Initializing` - script is initialising its environment
* `Launching web svc` - web services endpoint being launched. You cannot read the status without this!
* `checking TUN` - create and check network device
* `check creds` - the credentials check process is starting
* `waiting for cred` - the client is operating in production mode and is expecting a credential to be delivered to `pkidata`
* `valid cred` - the client has validated its credential and is happy
* `mkconfig` - the client is creating the VPN client configuration (ovpn)
* `connecting` - the client is in the process of connecting to a server
* `failed` - the client has failed to connect to a server
* `connected` - the client is connected.  This is the only status where `ip` is populated.
* `no conn` - the client is connected to the VPN, but it has temporarily lost connection to the server.

### Checking the status and the message ###

Most of the messages above mark temporary stages in the clients
initialisation process.  Only one states is final and (probably)
unrecoverable: `failed`.  If the status is `failed`, the "msg" entry
should provide additional information and should be displayed to the
user or administrator.


# Dependencies #

## Production mode dependencies ##

If running in production mode, the client depends on the following external services:

* The VPN server: within the container, the `vpnserver` name should resolve to the IP address of the VPN server.
* `cau-client` is expected to generate a credential from a suitable CA and place it in a shared volume traditionally called `pkidata` (see Environment, below).

## Unit Test Mode ##

If running as a unit test, the client needs:

* The VPN server, as above.
* Either the CA endpoint, or the CAU IP address (see Environment, below).


# Building Containers #

The test client illustrates the basics of building a client image.
When it comes to building containers, the following steps should be
followed:

## 1. Network capabilities ##

To build a container, you will need `--cap-add=NET_ADMIN` as the
client will need to set up a network device (viz., the VPN network.)

## 2. Client Credentials ##

The current implementation assumes that client credentials have been
generated and stored in /pkidata (which is presumably a mountpoint for
a volume), where, for some reason, the client certificate and key are
called server.crt and server.key, respectively.  The private key
must not be encrypted.

The container should thus mount the volume with the client credentials
on /pkidata.  Since we use these keys, there are no secrets in the
script, nor in the `.ovpn` file.  The `.ovpn` file, in fact, currently
has the hardwired certificate of the CA that issues the server's
credentials.

If they are not available, the vpnclient will:

1. If CAU_URL is set, it will contact the CAU directly, trying to
   obtain a credential, bypassing the cau-client.
   - Note that CAU_URL is not a URL, it is *IP*:*port*.
2. If CA_ENDPOINT is set but CAU_URL is not, the client will aim to
   contact the CA endpoint directly.
3. If CAU_URL and CA_ENDPOINT are **not** set, the client will
   loop/sleep, waiting for credentials to appear.
   - There are no defaults for these variables (see table below).

The default is that CAU_URL and CA_ENDPOINT are **not** set; as it is
expected that in a production environment, the credentials are made
available by the cau-client and written into the shared volume,
`pkidata`.

Note that there are two CA certificates, here called `fogca` and
`trustca`; the former is intended to protect the fog nodes (agents)
while the latter is intended to protect the (less dynamic)
infrastructure.  Some components use different names for these trust
anchors; the fog CA was previously known as "untrust" which is a bit
misleading; it is trusted, perhaps, less than the infrastructure CA
but it is of course not untrusted.


## 3. VPN server location ##

The `vpnserver` is meant to resolve to the location of the VPN server;
conventionally, the link is provided with `--link` when starting the
client, or configured in the `docker-compose.yml` file.  Running a
container by hand will likely need `--add-host`.

# Environment variables #

The script makes use of the following environment variables:

| Variable      | Required? | Description | Default |
| :--- | :---: | :--- | :--- |
| VPNINFO | no | File location to write metadata to | `/dev/null` |
| PING_INTERVAL | no | Time (seconds) between pings for status  | 10 |
| VPNSERVER     | no		| Location of VPN server | `vpnserver` |
| CN   	   	   	| no |commonName for a host certificate request | hostname |
| CAU_URL | no | CAU IP/port | no default |
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

## 4. PKI Trust Anchor Definition ##

As there is currently no trustworthy trust anchor distribution, some CA certificates are baked into the script.  However, in a production scenario, these can be overridden by predefining the `fogca.pem` and `trustca.pem` described above.


## 5. Versions ##

| Version | Descr. |
| :---: | :--- |
| 1.1.4 | Added writing status to shared volume for clients without network |
| 1.1.3 | Doesn't exit on VPN failure; API should be used to query status |
| 1.1.2 | Check vpnserver config; more status messages; running ping checks |
| 1.1.1 | Status web service API |
| 1.1.0 | Client designed to run on host's network |
| 1.0.X | Integration code |
