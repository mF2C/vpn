#!/bin/bash
#
# Script to run to bootstrap and launch the VPN server.  The script
# uses kylemanna/openvpn.  This image should have bash installed...
#
# Note that per the upstream image, server updates status into /tmp/openvpn-status.log

# First set default values for unset environment vars
# VPNSERVER_CONFIGDIR - config for VPN server
# TRUSTCA - endpoint for online CA; only used if no credential available
# TRUSTEDCA - alternative to TRUSTCA

# Config directory; recommended to make persistent
# 
if [ "x${VPNSERVER_CONFIGDIR}" = "x" ]; then
    VPNSERVER_CONFIGDIR=/etc/openvpn
fi


# PKI; trust anchors are fogca.pem and trustca.pem for, respectively, the Agent
# PKI and the infrastructure PKI.  The VPN server should have a certificate from
# the latter.

if [ "x${VPNSERVER_TRUSTANCHORS}" = "x" ]; then
    VPNSERVER_TRUSTANCHORS="${VPNSERVER_CONFIGDIR}/pki"
fi

# # Client credentials location
# if [ "x${PKIDATA}" = "x" ] ; then
#     PKIDATA=/pkidata
# fi


# This returns zero if the directory exists even if we don't have permission
# to create the directory.

if ! mkdir -p "${VPNSERVER_CONFIGDIR}" ; then
    echo >&2 Failed to create ${VPNSERVER_CONFIGDIR}
    exit 1
fi


# Our (common) name; if not set, use the hostname.  This project doesn't use
# server identity in the sense of RFC 2818 section 3.1; so the precise name
# doesn't matter so much.
if [ "x${CN}" = "x" ] ; then
    CN=`hostname`
    if [ "x${CN}" = "x" ] ; then
	echo >&2 Failure getting hostname
	CN=vpnserver
    fi
fi


OLDDIR=`pwd`
# if ! cd "${PKIDATA}" ; then
#     echo >&2 Could not CD into ${PKIDATA}
#     exit 1
# fi


if [ \! -d ${VPNSERVER_TRUSTANCHORS} ]; then
    if ! mkdir -p ${VPNSERVER_TRUSTANCHORS} ; then
	echo >&2 Failed to create "${VPNSERVER_TRUSTANCHORS}"
	exit 2
    fi
fi

if ! cd ${VPNSERVER_TRUSTANCHORS} ; then
    echo >&2 Failed to CD to "${VPNSERVER_TRUSTANCHORS}"
    exit 2
fi


# Following upstream, we put the credential into the server's
# /etc/openvpn directory, which means they get saved along with the
# rest of the configuration if the config directory is a mounted
# volume (as is recommended).  This is better than using the /pkidata
# because that location is used by the client, and if, for some
# reason, a client credential is made available on the server, it
# might clobber the server credential.  Or vice versa.


if [ \! -e servercert.pem ] ; then
    # if we are a server, we should be able to reach the CA... (in the cloud)
    # However, if we don't need it, it doesn't matter if the env var is not set
    if [ "x${TRUSTCA}" = "x" ]; then
	if [ "x${TRUSTEDCA}" = "x" ]; then
	    echo >&2 Neither TRUSTCA nor TRUSTEDCA environment variable is set
	    exit 1
	else
	    TRUSTCA="${TRUSTEDCA}"
	fi
    fi

    if touch server.tmp ; then
	rm server.tmp
    else
	echo >&2 Cannot write to `pwd` and no credential available
	exit 2
    fi

    
    # BUG BUG BUG Note the presence of the -k switch which says to turn off security checks.
    # This is because the current server (deployment) has a certificate from the wrong CA
    # BUG BUG BUG

    echo >&2 Getting credentials from web services endpoint "${TRUSTCA}"

    if curl -k --cacert trustca.pem -d "CN=${CN}" -H "Content-type: text/plain" -o server.tmp "${TRUSTCA}" ; then
	sed '/^-----BEGIN CERTIFICATE/,/^-----END CERTIFICATE/p;d' <server.tmp >servercert.pem
	sed '/^-----BEGIN.*PRIVATE KEY/,/^-----END.*PRIVATE KEY/p;d' <server.tmp >serverkey.pem
	chmod 600 serverkey.pem
	rm server.tmp
    else
	echo >&2 Something went wrong getting certificates from the CA
	if [ -e server.tmp ] ; then
	    echo >&2 "====Here's what we got:"
	    cat >&2 server.tmp
	    echo >&2 "====End of curl output"
	fi
	exit 2
    fi				# curl
fi				# ! -e servercert.pem

# Now check if it worked (or, if credentials were already there, if they are correct)
if openssl verify --CAfile trustca.pem servercert.pem ; then
    # Now check that the key and the certificate match (this construction requires bash)
    if diff -qs <(openssl x509 -pubkey -noout -in servercert.pem) <(openssl rsa -pubout -in serverkey.pem) ; then
	:
    else
	echo >&2 Server and private key mismatch, or private key encrypted
	exit 2
    fi
else
    echo >&2 missing server key or issued from unknown or inappropriate CA
    exit 2
fi


if [ \! -e dh.pem ] ; then
    echo >&2 Generating DH parameters - this may take a bit of time
    if ! openssl dhparam -out dh.pem 2048 ; then
	echo >&2 Generation of DH parameters failed
	exit 2
    fi
fi

if ! openssl dhparam -check -in dh.pem ; then
    echo >&2 DH parameter validation check failed
    exit 2
fi

# Now hand over to the upstream script

exec ovpn_run
