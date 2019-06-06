# vpn FOR Mf2c #

This directory contains server and client code for VPN in mF2C.  The
server uses the infrastructure PKI and the client the fog (sometimes
known as "untrust").  Thus, each has the CA certificate of each other;
these are currently committed with the source code due to a lack of
trust anchor distribution mechanism.

# What is here? #

There are two sub-components in this repository; the VPN server and a
VPN client.  Both can be deployed (together) with a `docker-compose`
file.

The vpnclient presented here is intended only for testing, because
you'd need to `exec` into the container to access the VPN.  In a
production environment, you would probably only need the server, and
install the client into whichever container would need to access VPN.
Please see the client documentation for more information.

# Requirements/Assumptions #

Both client and server assume the existence of the PKI(s) for mF2C,
the server making use of the infrastructure PKI (sometimes known as
"trusted") and the client making use of the Agent or fog PKI
(sometimes known as "untrusted").  In a production environment,
credentials should already be present in the default locations by the
time a client runs.  Both client and server will make an effort to
bootstrap themselves against the CA endpoints if their credentials are
missing.
