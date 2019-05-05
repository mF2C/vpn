#!/bin/sh
# Script to run to bootstrap and launch the VPN server
# The script assumes the ${PKIDATA} directory is available, with PKI
# trust anchors installed; and that it has permissions to do everything
# else that it needs...


# Config directory; recommended to make persistent
# 
CONFIGDIR=/etc/openvpn

# Credentials
PKIDATA=/pkidata




if ! mkdir -p "${CONFIGDIR}" ; then
    echo >&2 Failed to create ${CONFIGDIR}
    exit 1
fi
    

if [ \! -e ${PKIDATA}/vpnserver.crt ] ; then
    # if we are a server, we should be able to reach the CA...
    # However, if we don't need it, it doesn't matter if the env var is not set
    if [ "x${TRUSTCA}" = "x" ]; then
	echo >&2 TRUSTCA environment variable not set
	exit 1
    fi

    cd ${PKIDATA}
    curl 

# Our (common) name; if not set, use the hostname
if [ "x${CN}" = "x" ] ; then
    CN=`hostname`
    if [ "x${CN}" = "x" ] ; then
	echo >&2 Failure getting hostname
	CN=vpnserver
    fi
fi


# Server set up script

if ! cd ${CONFIGDIR} ; then
    
