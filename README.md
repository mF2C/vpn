# vpn FOR Mf2c #

This directory contains server and client code for VPN in mF2C.  The
server uses the infrastructure PKI and the client the fog (sometimes
known as "untrust").  Thus, each has the CA certificate of each other;
these are currently committed with the source code due to a lack of
trust anchor distribution mechanism.

