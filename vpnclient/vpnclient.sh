#!/bin/sh
# OpenVPN client setup and launch code for mF2C


# We're expecting Docker Compose to resolve the server name (or --link
# if launched manually).  The environment variable can override this
# feature.

if [ "x" = "x${VPNSERVER}" ] ; then
    VPNSERVER=vpnserver
fi


# Our (common) name; if not set, use the hostname
# TODO: maybe pick LSB part of the IP addr
if [ "x${CN}" = "x" ] ; then
    CN=`hostname`
    if [ "x${CN}" = "x" ] ; then
	echo >&2 Failure getting hostname
	exit 1
    fi
fi


# Check for TUN device, and create it if it's missing

if [ \! -d /dev/net ] ; then
    if ! mkdir /dev/net ; then
	echo >&2 "Unable to create /dev/net"
	exit 1
    fi
fi

if [ \! -c /dev/net/tun ] ; then
    if ! mknod /dev/net/tun c 10 200 ; then
	echo >&2 "Unable to create TUN device"
	exit 1
    fi
    chmod 0666 /dev/net/tun
fi


# Check for client credentials - should we do nothing if they're not
# there, or should we try to contact the CAU client?  In a production
# environment they should always be there, but for a test/integration
# setup, it might make sense to have a stab at creating them.

if [ "x${PKIDATA}" = "x" ]; then
    PKIDATA="/pkidata"
fi

if [ \! -d "${PKIDATA}" ] ; then
    echo >&2 Warning: Client credentials volume not mounted as expected on ${PKIDATA}
    if ! mkdir "${PKIDATA}" ; then
	# Might try a different location
	PKIDATA="./pkidata"
	if ! mkdir "${PKIDATA}" ; then
	    echo >&2 Failed to locate or create any PKIDATA folder
	    exit 2
	fi
    fi
fi

# We could usefully set up stuff in the ${PKIDATA} mountpoint because that's
# where the keys are located.

if ! cd ${PKIDATA} ; then
    echo >&2 Error ${PKIDATA} exists but cannot CD to it
    exit 2
fi



if [ \! -e server.crt ] || [ \! -e server.key ] ; then

    echo >&2 Warning: Client credentials not found in ${PKIDATA}
    if [ "x${CAU_URL}" = "x" ]; then
	echo >&2 Error no CAU endpoint defined and no credentials available - exiting
	exit 2

    else

	# Note the CAU_URL is not actually a URL
	CAU_ENDPOINT="https://${CAU_URL}/certauths/rest/it2untrustca"

	# Attempt to do our CAU client stuff, albeit limited to the local credential
	# ... useful for testing at least.  Assumes OpenSSL is available and uses
	# whatever is the default config (fingers crossed...)
	#openssl req -newkey rsa:1024 -keyout client.key -nodes -out client.csr -subj "/CN=${CN}" \
	#    && curl -d
	echo >&2 "This code does not yet work; the remote server sends an error message"
    exit 2
    fi
fi


# Now we can create the configuration file, overwriting an
# existing configuration file

if [ -e client.ovpn ] ; then
    # Only one backup!
    if ! mv client.ovpn client.ovpn.bak ; then
	echo >&2 Warning: failed to back up old config file
	# Not exiting here, but if moving the file doesn't work then
	# creating the new file might not work either...
    fi
fi


# Create an empty file with restricted permissions

cat </dev/null >client.ovpn
# if [ $? > 0 ] ; then
#     echo >&2 Failed to create client.ovpn file
#     exit 3
# fi
if ! chmod 0600 client.ovpn ; then
    echo >&2 Failed to restrict permissions on client.ovpn
    exit 3
fi

# Aside from the small race between the file being created and locked down, it
# should now be safe to overwrite the empty file with real config and it should
# inherit the restricted permissions


cat >client.ovpn <<EOF
client
nobind
dev tun
<ca>
-----BEGIN CERTIFICATE-----
MIIEBTCCAu2gAwIBAgIJAOIMpD3UIdv+MA0GCSqGSIb3DQEBCwUAMIGYMQswCQYD
VQQGEwJFVTERMA8GA1UECAwIU2FyZGVnbmExETAPBgNVBAcMCENhZ2xpYXJpMQ0w
CwYDVQQKDARtRjJDMRAwDgYDVQQLDAdJVDItRk9HMRYwFAYDVQQDDA1JVDItVHJ1
c3RlZENBMSowKAYJKoZIhvcNAQkBFhtzaGlybGV5LmNyb21wdG9uQHN0ZmMuYWMu
dWswHhcNMTkwMjExMTQzMTAzWhcNMjAxMDAzMTQzMTAzWjCBmDELMAkGA1UEBhMC
RVUxETAPBgNVBAgMCFNhcmRlZ25hMREwDwYDVQQHDAhDYWdsaWFyaTENMAsGA1UE
CgwEbUYyQzEQMA4GA1UECwwHSVQyLUZPRzEWMBQGA1UEAwwNSVQyLVRydXN0ZWRD
QTEqMCgGCSqGSIb3DQEJARYbc2hpcmxleS5jcm9tcHRvbkBzdGZjLmFjLnVrMIIB
IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA9vtKkdZgQhk6FKED/NKnVtdT
kfImBmlOLuPp8NwzqSO18ybuL64+c9WjQ6gdxjtxm1279ggqyWRV1CbtChxXESnp
jkHMU/XAd3hET75VtE847EwkpwwWzAVH8+sGRu30PG/z19tsM2bHgDhwE8AcC41Q
woN+oZHwBIdNmSFdtO2VnMyDqyyNFOT1/m6P0Bj8cfLOnXIFLUNJiWlYExjRImKZ
5uoZBD9JmjRZhe1j/SAxz8R3xk6S60OIJsxLU20s2998ZbyUNi9/r4CnryrQVev4
SyL+6Y3XAkLgmj/jsF9MvTMvil5TNZSJlL+M77PF81VtXjLi4Q1P2kwZRob3VQID
AQABo1AwTjAdBgNVHQ4EFgQUwjb6324pNQ0hFM+KNZnTZ/nYa3cwHwYDVR0jBBgw
FoAUwjb6324pNQ0hFM+KNZnTZ/nYa3cwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0B
AQsFAAOCAQEA0KguGIL06cXskbjaJk3MU17JS78fG6JE+hiNdPmpBM+V/bq1kRPN
5TSVonR4a9H4o3dAwVwcrZAlwMVHrCpHB+bLdOZZTuO8IJaYwgG/aLRKEJvMlt5K
HioV1O5GxglCyx4xxPzLyT2fHTWL1wZdrlLSgSnma2UWI+Do8wZ487wmX6pK6DJk
2DDpONi88tla8rVurBZ+91gZFyAaj/74t129ycXT6X5rjWbRMe1RVBjpqZr4b1ML
A++ebaiOOwvXKY0cQGoR7f0r5d9LkG0TGhzovzv1hWWWM6HNGxg3rWAOZBa9ADoo
NbO16X3c++xjxi/xpbmUhZDc9tPGTcN1bA==
-----END CERTIFICATE-----
</ca>
remote-cert-tls server
remote ${VPNSERVER} 1194 udp
key ${PKIDATA}/server.key
cert ${PKIDATA}/server.crt
key-direction 1
redirect-gateway def1
EOF

# if [ $? > 0 ] ; then
#     echo >&2 Failed to write config file client.ovpn into current location
#     exit 3
# fi

# Finally, launch openvpn client (as a daemon, by default)
if [ "x${VPN_DAEMON}" = "x" || "x${VPN_DAEMON}" = "xTRUE" ] ; then
    DAEMON="--daemon"
else
    DAEMON=""
fi

# This needs more checking because the daemon may fail to launch

openvpn --config client.ovpn ${DAEMON}

# if [ $? > 0 ] ; then
#     echo >&2 Failed to launch OpenVPN client
#     exit 5
# fi

#exit 0
