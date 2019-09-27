#!/bin/sh
# OpenVPN client setup and launch code for mF2C

# BEGIN ADMINISTRATOR CUSTOMISABLE PARTS

STATUSDIR=/usr/share/nginx/html/api
STATUSFILE="${STATUSDIR}/get_vpn_ip"
# Interval for pinging server to check whether we're connected
PING_INTERVAL=10

# END ADMINISTRATOR CUSTOMISABLE PARTS


# Note that sh function definitions are simpler than bash's
#
# This would be nice but doesn't work on all date implementations:
# "nextUpdate":"'`date --date "+ $PING_INTERVAL seconds" +"%Y%m%d %H:%M:%S%z"`

status () (
    echo '{"status":"'$1'","ip":"'$2'","server":"'$3'","lastUpdate":"'`date +"%Y%m%d %H:%M:%S%z"`'","stats":'$4'}' > ${STATUSFILE}
)

# mkdir -p is safe even on directories that already exist

if ! mkdir -p ${STATUSDIR} ; then
    echo >&2 Failed to create "${STATUSDIR}"
    exit 1
fi

# Let's try it out now!

status Initializing

if cat ${STATUSFILE}|grep -q Initializing ; then
    :
else
    echo >&2 FATAL FAILED TO WRITE STATUS FILE
    exit 1
fi



status "Launching web svc" ""

# Launch nginx - it is not launched by default, and it is helpful to
# have it provide status updates during configuration and startup, as
# well as after the connection.

if ! /usr/sbin/nginx -c /etc/nginx/nginx.conf ; then
    echo >&2 Failed to launch nginx server
    # Is this fatal?  Just means the status API is not available.
fi

# We're expecting Docker Compose to resolve the server name (or --link
# or --add-host if launched manually).  The environment variable can
# override this feature.

if [ "x" = "x${VPNSERVER}" ] ; then
    VPNSERVER=vpnserver
fi


if nslookup vpnserver >/dev/null 2>&1 ; then
    if ! ping -c 1 vpnserver ; then
	echo >&2 FATAL cannot reach vpnserver
	exit 1
    fi
else
    echo >&2 "FATAL 'vpnserver' does not resolve - check container config"
    exit 1
fi


# Our (common) name; if not set, use the hostname
# TODO: maybe pick LSB part of the IP addr and use that as part of
# the name
if [ "x${CN}" = "x" ] ; then
    CN=`hostname`
    if [ "x${CN}" = "x" ] ; then
	echo >&2 Failure getting hostname
	exit 1
    fi
fi


status "checking TUN" ''

# Check for TUN device, and create it if it's missing

if [ \! -d /dev/net ] ; then
    if ! mkdir /dev/net ; then
	echo >&2 "FATAL Unable to create /dev/net"
	exit 1
    fi
fi

if [ \! -c /dev/net/tun ] ; then
    if ! mknod /dev/net/tun c 10 200 ; then
	echo >&2 "FATAL unable to create TUN device"
	exit 1
    fi
    chmod 0666 /dev/net/tun
fi


# Check for client credentials - should we do nothing if they're not
# there, or should we try to contact the CAU client?  In a production
# environment they should always be there, but for a test/integration
# setup, it might make sense to have a stab at creating them.
#
# As a corollary, the /pkidata should then be writeable.

status "check creds" ""

if [ "x${PKIDATA}" = "x" ]; then
    PKIDATA="/pkidata"
fi

if [ \! -d "${PKIDATA}" ] ; then
    echo >&2 Warning: Client credentials volume not mounted as expected on ${PKIDATA}
    if ! mkdir "${PKIDATA}" ; then
	# Might try a different location
	PKIDATA="./pkidata"
	if ! mkdir "${PKIDATA}" ; then
	    echo >&2 FATAL Failed to locate or create any PKIDATA folder
	    exit 2
	fi
    fi
fi

# We could usefully set up stuff in the ${PKIDATA} mountpoint because that's
# where the keys are located.

if ! cd ${PKIDATA} ; then
    echo >&2 FATAL Error ${PKIDATA} exists but cannot CD to it
    exit 2
fi


# We will need a fogca certificate (previously known as untrust) if
# it's not already present; this is to check our own credential.
# Simple override by placing the 'fogca.pem' and 'trustca.pem' into
# the volume before launching the client.

if [ \! -e fogca.pem ] ; then
    echo >&2 "WARNING Recreating FogCA (nee Untrust) Trust Anchor"
    cat <<FOGCA >fogca.pem
-----BEGIN CERTIFICATE-----
MIIECTCCAvGgAwIBAgIJALELp789yWN0MA0GCSqGSIb3DQEBCwUAMIGaMQswCQYD
VQQGEwJFVTERMA8GA1UECAwIU2FyZGVnbmExETAPBgNVBAcMCENhZ2xpYXJpMQ0w
CwYDVQQKDARtRjJDMRAwDgYDVQQLDAdJVDItRk9HMRgwFgYDVQQDDA9JVDItVW50
cnVzdGVkQ0ExKjAoBgkqhkiG9w0BCQEWG3NoaXJsZXkuY3JvbXB0b25Ac3RmYy5h
Yy51azAeFw0xODEyMTMxMjM4MDJaFw0yMDA4MDQxMjM4MDJaMIGaMQswCQYDVQQG
EwJFVTERMA8GA1UECAwIU2FyZGVnbmExETAPBgNVBAcMCENhZ2xpYXJpMQ0wCwYD
VQQKDARtRjJDMRAwDgYDVQQLDAdJVDItRk9HMRgwFgYDVQQDDA9JVDItVW50cnVz
dGVkQ0ExKjAoBgkqhkiG9w0BCQEWG3NoaXJsZXkuY3JvbXB0b25Ac3RmYy5hYy51
azCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMinAXhMc2wzfFJ0pmd6
9elophYt9Crh7HB3WrG+4FwOPAyy/BNnN/jOvUz+39/vYCz/HvVxg9S37qDPBP53
tHRMBIJq1T04qDB506kh0Y4HM24zaXYDCWkIQkJam1IC2YDW1ly1XZEePG3mSm6+
fFEtCwSDpUQdsG7cfxUpstQWU9YrMKpn6HgMj1SnUVeQ0saOa81i7dUEeYxKopuw
g0pHhIS9AyFILzYYBaUZrEJlBlXgEPgObo8EGMHX5GFK2879XILQetFFv9r69qlz
DNGwuIszmu+JpOxn5EhYSvEZRGJpbKOX7UVTcqYoBxFaRKfKuX3dWFwAWn6t81B3
PEcCAwEAAaNQME4wHQYDVR0OBBYEFLZypR5e+HoSRnQEdSiW40qniMQ3MB8GA1Ud
IwQYMBaAFLZypR5e+HoSRnQEdSiW40qniMQ3MAwGA1UdEwQFMAMBAf8wDQYJKoZI
hvcNAQELBQADggEBAHqoGMCBPadJRF0G1OjbT6dC5PVA8neexUIeaE4Wt/BR8smJ
TfGUrF/TSOhc7RRhodgeoM5VfYCVu6L49JpLpBUEqCr/rt3t4yXIO68im2tIbi83
VPeRYUMpAeJXNwEnPgwFBDviXB/CZ330VDwp0SGYe6zqmjP/P+63snGSqVWtxnZE
IQiGTxGjP6i25lsXEnBrq975J63LjMB6tH7AY77xp6eB5njSYsg76Of4suvt8B72
nzm9O51VY9YxBoG/ODQUg6xO4zYdl6ItvRKyZAgJfLhkOkVrApg+u746U49x9FQW
5o0MK4dzYZN28LQfXHmIctaZP0njv3WnbbIevHA=
-----END CERTIFICATE-----
FOGCA
fi

    # Client credentials might appear later, as cau-client is expected to
# write them into the volume, but it might not have finished obtaining
# them yet.

if [ "x" = "x${CAU_URL}" ] && [ "x" = "x${CA_ENDPOINT}" ] ; then

    DELAY=0
    DELAYTICK=2

    status "waiting for cred" ""

    # We have no means of getting a credential ourselves, so must
    # trust external parties to deliver it for us into pkidata.
    while [ \! -e server.crt ] || [ \! -e server.key ] ; do
	echo >&2 vpnclient awaiting keys to be placed into PKIDATA - ${DELAY} seconds
	sleep ${DELAYTICK}
	DELAY=`expr $DELAY + $DELAYTICK`
    done
    sleep 1			# bit of extra delay, in case writing files is slow?

elif [ \! -e server.crt ] || [ \! -e server.key ] ; then

    echo >&2 Warning: Client credentials not found in ${PKIDATA} but CAU_URL or CA_ENDPOINT suggests to try rekeying

    # Please excuse the inelegant writing TRUSTCA ourselves, if it's
    # not already present.  The project has no trust anchor
    # distribution -- this would need customising in an independent
    # deployment.
    #
    # The trust anchor is needed to check the CAU and CA endpoints.
    # It is also needed to check the VPN server but this is done by
    # the one in the OVPN file.  Obviously we only write it if it's
    # not already there, as a last resort.

    if [ \! -e trustca.pem ] ; then
	echo >&2 WARNING Recreating TrustCA trust anchor
	cat <<TRUSTCA >trustca.pem
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
TRUSTCA
    fi

    # Generate a CSR.  For some reason, the client is called 'server'
    # Also note these are to be PEM formatted, not DER (despite the names)
    CSRFILE="${PKIDATA}/server.csr"
    CRTFILE="${PKIDATA}/server.crt"
    
    # XXX Should really use elliptic curve but currently RSA is supported
    # We don't specify a config but hopefully it should work...
    if openssl req -newkey rsa:1024 -nodes -keyout "${PKIDATA}/server.key" -out "${CSRFILE}" -subj "/CN=${CN}" ; then
	:
    else
	echo >&2 Fatal error generating CSR
	exit 2
    fi

    CERT_OK=0

    if [ "x${CAU_URL}" = "x" ]; then
	echo >&2 Error no CAU endpoint defined and no credentials available
	if [ "x${CA_ENDPOINT}" = "x" ]; then
	    echo >&2 FATAL No credentials and no CA endpoint
	    exit 2
	fi
	# CA is tried below if CERT_OK stays 0
    else
	# Note the CAU_URL is not actually a URL; it is host:port
	# This code might work for the CAU
	if openssl s_client -connect "${CAU_URL}" -CAfile "${PKIDATA}/trustca.pem" -verify_return_error < ${CSRFILE} > "${PKIDATA}/server.crt" ; then
	    # Check that it actually worked...
	    if openssl verify -CAfile "${PKIDATA}/fogca.pem" "${CRTFILE}" ; then
		CERT_OK=1
	    else
		echo >&2 "Failed to get certificate from CAU; trying CA directly"
	    fi
	else
	    echo >&2 "Failed to connect and get certificate from CAU; trying CA directly"
	fi
    fi				# end CAU_URL

    if ! expr $CERT_OK ; then
	# Can't happen - the client will loop (above) waiting for credentials
	if [ "x${CA_ENDPOINT}" = "x" ]; then
	    echo >&2 FATAL Client credentials are needed but no CA endpoint specified
	    exit 2
	fi
	# note the format of the POST (binary)
	if curl --cacert "${PKIDATA}/trustca.pem" --data-binary "@${CSRFILE}" -H "Content-type: text/plain" "${CA_ENDPOINT}" > "${CRTFILE}" ; then
	    CERT_OK=1
	else
	    echo >&2 FATAL Failed to contact the CA endpoint
	    exit 2
	fi
    fi
fi


status "valid cred" ""

# Now re-check the certificate
if openssl verify -CAfile fogca.pem server.crt ; then
    # Now check the private key
    if openssl rsa -check -noout -in server.key ; then
	# Now check that the key and the certificate match; copied more extensive test from the server
	# except we're not in bash so cannot use the convenient <() construct
	openssl x509 -pubkey -noout -in server.crt > pubkey1.pem
	openssl rsa -pubout -in server.key > pubkey2.pem
	if diff -qs pubkey1.pem pubkey2.pem ; then
	    rm -r pubkey1.pem pubkey2.pem
	else
	    echo >&2 FATAL Server and private key mismatch, or private key encrypted
	    exit 2
	fi
    else
	echo >&2 FATAL Private key check failed, or private key encrypted
	exit 2
    fi
else
    echo >&2 "FATAL Certificate check failed; certificate is invalid or not issued by FOGCA"
    exit 2
fi

echo >&2 INFO Credentials checks passed, creating OVPN



# Now we can create the configuration file, overwriting an
# existing configuration file

status mkconfig ""

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
    echo >&2 FATAL Failed to restrict permissions on client.ovpn
    exit 3
fi

# Aside from the small race between the file being created and locked down, it
# should now be safe to overwrite the empty file with real config and it should
# inherit the restricted permissions
#
# Note that the CA certificate in the config below is TRUSTCA, needed
# to validate the server certificate

cat >client.ovpn <<EOF
client
nobind
dev tun
ca ${PKIDATA}/trustca.pem
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


echo >&2 "INFO OVPN created; launching client"

status connecting

if ! openvpn --config client.ovpn --daemon ; then
    status failed
    echo >&2 FATAL failed to launch VPN client
    exit 5
fi

# Now we try to get the IP address
# It could still loop forever if something goes wrong...?

while ! ip addr show tun0 >/dev/null 2>&1
do echo >&2 INFO Waiting for device/IP address from VPN daemon
sleep 1
done


# The ip addr command has more consistent output format than ifconfig
#
# Gathering data into a variable has the effect of aggregating it into
# a single line
M=`ip addr show tun0`

CIDR=`echo $M|sed 's/^.*inet //;s/ .*$//'`
IP=`echo $CIDR|sed 's/\/.*$//'`


status "connected" "${IP}"

echo >&2 INFO CIDR = "'$CIDR'"
echo >&2 INFO IP = "'$IP'"


# Note that Alpine has both sed and awk,
# albeit in tiny busybox versions - the code below would have been
# somewhat cleaner in gawk where 'patsplit' neatly works

SERVER=`echo $CIDR| sed "s/[\.\/]/ /g" | awk '
function itoa(i) {
    o[1] = and(rshift(i,24),0xFF)
    o[2] = and(rshift(i,16),0xFF)
    o[3] = and(rshift(i,8),0xFF)
    o[4] = and(i,0xFF)
    return o[1]"."o[2]"."o[3]"."o[4]
}

# We check the pattern - twice!  Can also be used for the script to
# match other patterns, e.g. IPv6, or different ways of passing the
# netmask  to the script.

/^[[:digit:]]+ [[:digit:]]+ [[:digit:]]+ [[:digit:]]+ [[:digit:]]+/ {
    a[1] = $1
    a[2] = $2
    a[3] = $3
    a[4] = $4
    a[5] = $5

    # 32 bit unsigned integers are OK on all awks...
    # busybox awk can only OR two numbers at a time
    client=or(lshift(a[1],24), lshift(a[2],16))
    client=or(client, lshift(a[3],8))
    client=or(client, a[4])

    # Number of least significant zero bits in netmask
    nmzbits=32-a[5]

    # Clear the lower bits and add 1
    server=or(lshift(rshift(client,nmzbits),nmzbits),1)

    print itoa(server)
}'`

# The extra awk call above is because the main script by default
# outputs both the input and the output.

if [ $? -gt 0 ] || [ "x${SERVER}" = "x" ] ; then
    echo >&2 "FATAL Failed to derive server's VPN address"
    exit 5
fi

echo >&2 INFO Found server "${SERVER}"


# We use ping to check whether the server is reachable.  However, we
# need to guard for other kinds of weird failures, and there's more
# than one implementation of ping -

# Unfortunately ping's exit code does not distinguish between a bad
# address and a lost connection/unreachable host

PING_GOOD=0
PING_BAD=0
PING_UGLY=0

stats () echo '{"good":"'$1'","noconn":"'$2'","error":"'$3'","total":"'`expr $1 + $2 + $3`'"}'


while true
do sleep ${PING_INTERVAL}
   PING=`ping -c 1 ${SERVER} 2>&1`
   if [ $? -eq 0 ]; then
       PING_GOOD=`expr $PING_GOOD + 1`
       STATS=`stats $PING_GOOD $PING_BAD $PING_UGLY`
       status "connected" "${IP}" "${SERVER}" "${STATS}"
   elif echo $PING | grep -q '^PING.*transmitted' ;  then
       # Probably a normal ping but connection lost
       PING_BAD=`expr $PING_BAD + 1`
       STATS=`stats $PING_GOOD $PING_BAD $PING_UGLY`
       status "lost conn" "${IP}" "${SERVER}" "${STATS}"
   else
       PING_UGLY=`expr $PING_UGLY + 1`
       STATS=`stats $PING_GOOD $PING_BAD $PING_UGLY`
       status "address error" "${IP}" "${SERVER}" "${STATS}"
   fi
done
