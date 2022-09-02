# WLAN Information SNMP Agent (wlanisa.sh)

Wlanisa is a SNMP agent written in shell script (sh) that exposes the list of
WLAN interfaces and currently connected wireless clients. It uses
[Net-SNMP](http://www.net-snmp.org/)'s ["pass"](https://net-snmp.sourceforge.io/wiki/index.php/Net-snmp_extensions) [^1] feature to extend the SNMP server.

It is meant to be used on home routers/access points based on
[BusyBox](https://www.busybox.net/). It requires Net-SNMP server (snmpd) and the
Broadcom's `wl` utility.

Wlanisa.sh was born of the need to list the currently connected wireless clients
of a Netgear R7000 router running [FreshTomato](https://freshtomato.org/) version
2022.3. It's usually possible to obtain such list by visiting the router's device
list page. However, that requires logging into the router (and storing credentials
to it) and it requires parsing content from the router's web pages. Even though
it's possible to write such code, it's cumbersome and prone to broke if the page
were to ever change. Obtaining such information through SNMP is a better approach.

This SNMP agent gets all information it needs from the router's NVRAM and from
the output of the `wl` utility. It exposes the same information currently provided
by router's device list page. However, it can be modified to expose any other
information available either through `wl` or any other method.

## Installation

Copy wlanisa.sh over to your router or access point. In order for it to survive
reboots, enable JFFS and copy it under `/jffs`. Ensure it can be executed by
`snmpd`:

```
chmod a+x /jffs/wlanisa.sh
```

Configure `snmpd` to delegate our OID tree to wlanisa by adding these lines to
your `/etc/snmpd.conf`:

```
pass .1.3.6.1.4.1.9999 /jffs/wlanisa.sh
view all included .1.3.6.1.4.1.9999
```

Note that the use of the OID tree rooted at `.1.3.6.1.4.1.9999` (enterprise 9999)
was done as an example only and it should be replaced by a real OID before use.

## Clients and MIBs

In order for the information to be readable by clients, a MIB is needed. MIB file
`WLAN-INFO-MIB.txt` is provided to help with OID translation.

Here's an example of the output of `snmpwalk` running against that router:

```
# snmpwalk -v 2c -c public -m +WLAN-INFO-MIB 192.168.1.8 .1.3.6.1.4.1.9999.2.10
WLAN-INFO-MIB::wlanInterfaceCount.0 = Counter32: 2
WLAN-INFO-MIB::wlanInterfaceIndex.1 = INTEGER: 1
WLAN-INFO-MIB::wlanInterfaceIndex.2 = INTEGER: 2
WLAN-INFO-MIB::wlanInterfaceBssid.1 = STRING: "<redacted>" (MAC in the form "aa:bb:cc:dd:ee:ff")
WLAN-INFO-MIB::wlanInterfaceBssid.2 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanInterfaceSsid.1 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanInterfaceSsid.2 = STRING: <redacted_WLAN2>
WLAN-INFO-MIB::wlanInterfaceChannel.1 = INTEGER: 1
WLAN-INFO-MIB::wlanInterfaceChannel.2 = INTEGER: 38
WLAN-INFO-MIB::wlanInterfaceNoiseFloor.1 = INTEGER: -91
WLAN-INFO-MIB::wlanInterfaceNoiseFloor.2 = INTEGER: -90
WLAN-INFO-MIB::wlanClientCount.0 = Counter32: 19
WLAN-INFO-MIB::wlanClientIndex.1 = INTEGER: 1
WLAN-INFO-MIB::wlanClientIndex.2 = INTEGER: 2
WLAN-INFO-MIB::wlanClientIndex.3 = INTEGER: 3
WLAN-INFO-MIB::wlanClientIndex.4 = INTEGER: 4
WLAN-INFO-MIB::wlanClientIndex.5 = INTEGER: 5
WLAN-INFO-MIB::wlanClientIndex.6 = INTEGER: 6
WLAN-INFO-MIB::wlanClientIndex.7 = INTEGER: 7
WLAN-INFO-MIB::wlanClientIndex.8 = INTEGER: 8
WLAN-INFO-MIB::wlanClientIndex.9 = INTEGER: 9
WLAN-INFO-MIB::wlanClientIndex.10 = INTEGER: 10
WLAN-INFO-MIB::wlanClientIndex.11 = INTEGER: 11
WLAN-INFO-MIB::wlanClientIndex.12 = INTEGER: 12
WLAN-INFO-MIB::wlanClientIndex.13 = INTEGER: 13
WLAN-INFO-MIB::wlanClientIndex.14 = INTEGER: 14
WLAN-INFO-MIB::wlanClientIndex.15 = INTEGER: 15
WLAN-INFO-MIB::wlanClientIndex.16 = INTEGER: 16
WLAN-INFO-MIB::wlanClientIndex.17 = INTEGER: 17
WLAN-INFO-MIB::wlanClientIndex.18 = INTEGER: 18
WLAN-INFO-MIB::wlanClientIndex.19 = INTEGER: 19
WLAN-INFO-MIB::wlanClientMac.1 = STRING: "<redacted>" (MAC in the form "aa:bb:cc:dd:ee:ff")
WLAN-INFO-MIB::wlanClientMac.2 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.3 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.4 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.5 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.6 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.7 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.8 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.9 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.10 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.11 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.12 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.13 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.14 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.15 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.16 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.17 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.18 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientMac.19 = STRING: "<redacted>"
WLAN-INFO-MIB::wlanClientSsid.1 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.2 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.3 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.4 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.5 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.6 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.7 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.8 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.9 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.10 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.11 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.12 = STRING: <redacted_WLAN1>
WLAN-INFO-MIB::wlanClientSsid.13 = STRING: <redacted_WLAN2>
WLAN-INFO-MIB::wlanClientSsid.14 = STRING: <redacted_WLAN2>
WLAN-INFO-MIB::wlanClientSsid.15 = STRING: <redacted_WLAN2>
WLAN-INFO-MIB::wlanClientSsid.16 = STRING: <redacted_WLAN2>
WLAN-INFO-MIB::wlanClientSsid.17 = STRING: <redacted_WLAN2>
WLAN-INFO-MIB::wlanClientSsid.18 = STRING: <redacted_WLAN2>
WLAN-INFO-MIB::wlanClientSsid.19 = STRING: <redacted_WLAN2>
WLAN-INFO-MIB::wlanClientRssi.1 = INTEGER: -50
WLAN-INFO-MIB::wlanClientRssi.2 = INTEGER: -46
WLAN-INFO-MIB::wlanClientRssi.3 = INTEGER: -67
WLAN-INFO-MIB::wlanClientRssi.4 = INTEGER: -47
WLAN-INFO-MIB::wlanClientRssi.5 = INTEGER: -35
WLAN-INFO-MIB::wlanClientRssi.6 = INTEGER: -64
WLAN-INFO-MIB::wlanClientRssi.7 = INTEGER: -54
WLAN-INFO-MIB::wlanClientRssi.8 = INTEGER: -54
WLAN-INFO-MIB::wlanClientRssi.9 = INTEGER: -62
WLAN-INFO-MIB::wlanClientRssi.10 = INTEGER: -64
WLAN-INFO-MIB::wlanClientRssi.11 = INTEGER: -45
WLAN-INFO-MIB::wlanClientRssi.12 = INTEGER: -44
WLAN-INFO-MIB::wlanClientRssi.13 = INTEGER: -74
WLAN-INFO-MIB::wlanClientRssi.14 = INTEGER: -84
WLAN-INFO-MIB::wlanClientRssi.15 = INTEGER: -73
WLAN-INFO-MIB::wlanClientRssi.16 = INTEGER: -39
WLAN-INFO-MIB::wlanClientRssi.17 = INTEGER: -52
WLAN-INFO-MIB::wlanClientRssi.18 = INTEGER: -73
WLAN-INFO-MIB::wlanClientRssi.19 = INTEGER: -70
WLAN-INFO-MIB::wlanClientTxRate.1 = INTEGER: 144444
WLAN-INFO-MIB::wlanClientTxRate.2 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientTxRate.3 = INTEGER: 72222
WLAN-INFO-MIB::wlanClientTxRate.4 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientTxRate.5 = INTEGER: 72222
WLAN-INFO-MIB::wlanClientTxRate.6 = INTEGER: 144444
WLAN-INFO-MIB::wlanClientTxRate.7 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientTxRate.8 = INTEGER: 72222
WLAN-INFO-MIB::wlanClientTxRate.9 = INTEGER: 26000
WLAN-INFO-MIB::wlanClientTxRate.10 = INTEGER: 65000
WLAN-INFO-MIB::wlanClientTxRate.11 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientTxRate.12 = INTEGER: 130000
WLAN-INFO-MIB::wlanClientTxRate.13 = INTEGER: 243000
WLAN-INFO-MIB::wlanClientTxRate.14 = INTEGER: 216000
WLAN-INFO-MIB::wlanClientTxRate.15 = INTEGER: 200000
WLAN-INFO-MIB::wlanClientTxRate.16 = INTEGER: 400000
WLAN-INFO-MIB::wlanClientTxRate.17 = INTEGER: 400000
WLAN-INFO-MIB::wlanClientTxRate.18 = INTEGER: 200000
WLAN-INFO-MIB::wlanClientTxRate.19 = INTEGER: 200000
WLAN-INFO-MIB::wlanClientRxRate.1 = INTEGER: 24000
WLAN-INFO-MIB::wlanClientRxRate.2 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientRxRate.3 = INTEGER: 19500
WLAN-INFO-MIB::wlanClientRxRate.4 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientRxRate.5 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientRxRate.6 = INTEGER: 11000
WLAN-INFO-MIB::wlanClientRxRate.7 = INTEGER: 6000
WLAN-INFO-MIB::wlanClientRxRate.8 = INTEGER: 72222
WLAN-INFO-MIB::wlanClientRxRate.9 = INTEGER: 52000
WLAN-INFO-MIB::wlanClientRxRate.10 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientRxRate.11 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientRxRate.12 = INTEGER: 1000
WLAN-INFO-MIB::wlanClientRxRate.13 = INTEGER: 216000
WLAN-INFO-MIB::wlanClientRxRate.14 = INTEGER: 120000
WLAN-INFO-MIB::wlanClientRxRate.15 = INTEGER: 200000
WLAN-INFO-MIB::wlanClientRxRate.16 = INTEGER: 400000
WLAN-INFO-MIB::wlanClientRxRate.17 = INTEGER: 6000
WLAN-INFO-MIB::wlanClientRxRate.18 = INTEGER: 180000
WLAN-INFO-MIB::wlanClientRxRate.19 = INTEGER: 180000
WLAN-INFO-MIB::wlanClientTimeConnected.1 = INTEGER: 2121
WLAN-INFO-MIB::wlanClientTimeConnected.2 = INTEGER: 5606
WLAN-INFO-MIB::wlanClientTimeConnected.3 = INTEGER: 10518
WLAN-INFO-MIB::wlanClientTimeConnected.4 = INTEGER: 25530
WLAN-INFO-MIB::wlanClientTimeConnected.5 = INTEGER: 71268
WLAN-INFO-MIB::wlanClientTimeConnected.6 = INTEGER: 158451
WLAN-INFO-MIB::wlanClientTimeConnected.7 = INTEGER: 158531
WLAN-INFO-MIB::wlanClientTimeConnected.8 = INTEGER: 179389
WLAN-INFO-MIB::wlanClientTimeConnected.9 = INTEGER: 179403
WLAN-INFO-MIB::wlanClientTimeConnected.10 = INTEGER: 179411
WLAN-INFO-MIB::wlanClientTimeConnected.11 = INTEGER: 290205
WLAN-INFO-MIB::wlanClientTimeConnected.12 = INTEGER: 614400
WLAN-INFO-MIB::wlanClientTimeConnected.13 = INTEGER: 5396
WLAN-INFO-MIB::wlanClientTimeConnected.14 = INTEGER: 6710
WLAN-INFO-MIB::wlanClientTimeConnected.15 = INTEGER: 16592
WLAN-INFO-MIB::wlanClientTimeConnected.16 = INTEGER: 29328
WLAN-INFO-MIB::wlanClientTimeConnected.17 = INTEGER: 66089
WLAN-INFO-MIB::wlanClientTimeConnected.18 = INTEGER: 179399
WLAN-INFO-MIB::wlanClientTimeConnected.19 = INTEGER: 179401
```

## Schema

Assuming our root at `.1.3.6.1.4.1.9999.2.10`, the OID subtree under `root`.1
(or `.1.3.6.1.4.1.9999.2.10.1`) will contain information about the device's
WLAN interfaces. Value `root`.1.1 represents the count of interfaces, and interface
information is listed under `root`.1.2.1. Currently the following is listed for
each interface:

- Index
- BSSID
- SSID
- Channel being used
- Noise floor (in dBm)

The OID subtree under `root`.2 contains information about currently connected
wireless clients. The value under `root`.2.1 represents the count of wireless
clients, while the client information is listed under OID `root`.2.2.1. Currently,
the following is listed for each connected wireless client:

- Index
- MAC address
- SSID it is connected to
- RSSI (in dBm)
- Transmit rate (in kbps)
- Receive rate (in kbps)
- Time connected (in seconds)

For more details about the data and data types available, consult the WLAN-INFO-MIB.TXT file.

## Known Issues

**It's slow!**

The pass feature of Net-SNMP works by invoking the script for every single OID.
For the output above, the script was called 145 times.

## Future Plans

Look into using [`dlmod`](http://www.net-snmp.org/wiki/index.php/TUT:Writing_a_Dynamically_Loadable_Object) instead of `pass` in Net-SNMP. Using
`dlmod` would mean the code is always resident and available, but it requires a
full rewrite of the agent in C, which is more complicated and will demand more
time.

[^1]: Unfortunately, `snmpd` on FreshTomato does not seems to support the `pass_persist`
feature, which could make wlanisa faster by avoiding the multiple invocations.
