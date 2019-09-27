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
    "lastUpdate" : "20190927 09:46:07+0000"
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

# Environment #

The script makes use of the following environment variables:

| Variable      | Required? | Description | Default |
| :--- | :---: | :--- | :--- |
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
| 1.1.2 | Check vpnserver config; more status messages; running ping checks |
| 1.1.1 | Status web service API |
| 1.1.0 | Client designed to run on host's network |
| 1.0.X | Integration code |
