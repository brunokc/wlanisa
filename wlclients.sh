#!/bin/sh
# Lists currently connected wireless clients
# Meant to be used on routers based on busybox.
# Requires the Broadcom wl uitility installed

ALL_WLAN_IFACES="$(nvram get wl_ifnames) $(nvram get wl0_vifs) $(nvram get wl1_vifs)"
for iface in $ALL_WLAN_IFACES; do
    for mac in $(wl -i $iface assoclist | awk '{print tolower($2)}'); do
        rssi=$(wl -i $iface rssi $mac)
        stainfo=$(wl -i $iface sta_info $mac)

        echo $iface: $mac: RSSI=$rssi
    done
done
