#!/bin/sh -f
#
# WLAN Information SNMP Agent (wlanisa.sh)
#
# SNMP agent that exposes the list of WLAN interfaces and currently connected
# wireless clients via SNMP through Net-SNMP's "pass/pass_persist" feature.
#
# Meant to be used on home routers/access points based on busybox. It requires
# Net-SNMP server (snmpd) and the Broadcom wl utility.
#
# Install it by adding these lines to your /etc/snmpd.conf:
#
# pass .1.3.6.1.4.1.9999 <path_to_this_script>
# view all included .1.3.6.1.4.1.9999
#
# Note that the use of the OID .1.3.6.1.4.1.9999 (enterprise 9999) is an example
# and it should be replaced by a real one.
#
#set -x

LOG_FILE=/var/log/wlanisa.log
PID_FILE=/var/run/wlanisa.pid
CLIENTS_CACHE_FILE=/tmp/wlanisa.clients.cache
CLIENTS_CACHE_AGE_SEC=30

# WLAN-CLIENTS-MIB
OID_ROOT=".1.3.6.1.4.1.9999"
OID_NETWORK_ROOT=$OID_ROOT.2
OID_WLAN_ROOT=$OID_NETWORK_ROOT.10
OID_WLAN_INTERFACES=$OID_WLAN_ROOT.1
OID_WLAN_INTERFACE_COUNT=$OID_WLAN_INTERFACES.1
OID_WLAN_INTERFACE_TABLE=$OID_WLAN_INTERFACES.2
OID_WLAN_INTERFACE_ENTRY=$OID_WLAN_INTERFACE_TABLE.1
OID_WLAN_CLIENTS=$OID_WLAN_ROOT.2
OID_WLAN_CLIENT_COUNT=$OID_WLAN_CLIENTS.1
OID_WLAN_CLIENT_TABLE=$OID_WLAN_CLIENTS.2
OID_WLAN_CLIENT_ENTRY=$OID_WLAN_CLIENT_TABLE.1

# Index, BSSID, SSID, Channel, Noise Floor
WLAN_INTERFACE_TABLE_SNMP_PASS_TYPES="integer,string,string,integer,integer,integer"
WLAN_INTERFACE_TABLE_FIELD_COUNT=$(echo $WLAN_INTERFACE_TABLE_SNMP_PASS_TYPES | tr ',' '\n' | wc -l)

# Index, Mac, SSID, RSSI, Tx Rate, Rx Rate, Time Connected
WLAN_CLIENT_TABLE_SNMP_PASS_TYPES="integer,string,string,integer,integer,integer,integer"
WLAN_CLIENT_TABLE_FIELD_COUNT=$(echo $WLAN_CLIENT_TABLE_SNMP_PASS_TYPES | tr ',' '\n' | wc -l)

trim() {
    local var="$*"
    # Remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

ALL_WLAN_IFACES="$(trim $(nvram get wl_ifnames) $(nvram get wl0_vifs) $(nvram get wl1_vifs))"

get_interfaces_info() {
    index=1
    for iface in $ALL_WLAN_IFACES; do
        local bssid=$(wl -i $iface bssid | awk '{print tolower($0)}')
        local ssid=$(wl -i $iface ssid | cut -d "\"" -f 2)
        local noise=$(wl -i $iface noise)
        local temp=$(wl -i $iface phy_tempsense | cut -d ' ' -f 1)
        wl -i $iface channel | {
            while read line; do
                if [[ "$line" =~ "current mac channel.*" ]]; then
                    channel=$(trim ${line##*[[:space:]]})
                fi
            done

            echo index=$index,bssid=$bssid,ssid="$ssid",channel=$channel,noise=$noise,temp=$temp
        }
        index=$((index + 1))
    done
}

cache_current_clients() {
    # Initialize output file
    > $CLIENTS_CACHE_FILE

    index=1
    for iface in $ALL_WLAN_IFACES; do
        ssid=$(wl -i $iface ssid | cut -d "\"" -f 2)
        for mac in $(wl -i $iface assoclist | awk '{print tolower($2)}'); do
            rssi=$(wl -i $iface rssi $mac)
            wl -i $iface sta_info $mac | {
                while read line; do
                    # "in network (\d+) seconds"
                    if [[ "$line" =~ "in network .* seconds" ]]; then
                        line=${line#*network }
                        line=${line% seconds}
                        connTime=$line
                    elif [[ "$line" =~ "rate of last .* pkt:" ]]; then
                        line=${line#*last }
                        direction=${line% pkt*}
                        line=${line#*pkt: }
                        speed=${line% kbps}
                        case $direction in
                            "tx") tx=$speed;;
                            "rx") rx=$speed;;
                        esac
                    fi
                done

                echo index=$index,mac=$mac,ssid="$ssid",RSSI=$rssi,tx=$tx,rx=$rx,t=$connTime >> $CLIENTS_CACHE_FILE
            }
            index=$((index + 1))
        done
    done
}

refresh_client_cache_if_needed() {
    local now=$(date +%s)
    local cache_age=0
    if [ -f $CLIENTS_CACHE_FILE ]; then
        cache_age=$(date +%s -r $CLIENTS_CACHE_FILE)
    fi

    local aged_out=$(( (now - cache_age) > $CLIENTS_CACHE_AGE_SEC))
    if [ $aged_out -eq 1 ]; then
        cache_current_clients
    fi
}

get_oid_part() {
    local oid=$1
    local index=$2
    local parts=$(echo $oid | tr '.' '\n' | grep -v "^$")
    if [ $index -lt 0 ]; then
        local num_parts=$(echo $oid | tr '.' '\n' | grep -v "^$" | wc -l)
        index=$((num_parts + index + 1))
    fi
    echo $oid | tr '.' '\n' | grep -v "^$" | awk "NR==$index { print; exit; }"
}

get_record_part() {
    # Assumes records with key/value pairs separated by commas
    # Examples:
    # index=1,bssid=c4:04:15:1b:d3:a3,ssid=BKCWLAN-N600,channel=1,noise=-87 (interfaces)
    # index=1,mac=00:51:ed:fe:34:e1,ssid=BKCWLAN-N600,RSSI=-68,tx=72222,rx=19500,t=134
    local record=$1
    local field_number=$2
    local field=$(echo $record | cut -d "," -f $field_number)
    echo ${field#*=}
}

find_next_interface() {
    local oid=$1
    local rest=${oid#$OID_WLAN_INTERFACE_ENTRY.}
    local field_index=$(get_oid_part $rest 1)
    local iface_index=$(get_oid_part $rest 2)
    iface_index=${iface_index:-0}
    local iface_count=$(echo $ALL_WLAN_IFACES | tr ' ' '\n' | wc -l)
    if [ $iface_index -eq $iface_count -a $field_index -eq $WLAN_INTERFACE_TABLE_FIELD_COUNT ]; then
        # Reached the last field of the last interface. Point to the clients count
        echo $OID_WLAN_CLIENT_COUNT.0
    else
        if [ $iface_index -lt $iface_count ]; then
            iface_index=$((iface_index + 1))
        elif [ $field_index -lt $WLAN_INTERFACE_TABLE_FIELD_COUNT ]; then
            iface_index=1
            field_index=$((field_index + 1))
        fi
        echo $OID_WLAN_INTERFACE_ENTRY.$field_index.$iface_index
    fi
}

find_next_client() {
    local oid=$1
    local rest=${oid#$OID_WLAN_CLIENT_ENTRY.}
    local field_index=$(get_oid_part $rest 1)
    local client_index=$(get_oid_part $rest 2)
    client_index=${client_index:-0}

    refresh_client_cache_if_needed
    local client_count=$(cat $CLIENTS_CACHE_FILE | wc -l)
    if [ $client_index -eq $client_count -a $field_index -eq $WLAN_CLIENT_TABLE_FIELD_COUNT ]; then
        # Reached the last field of the last client. We're done
        :
    else
        if [ $client_index -lt $client_count ]; then
            client_index=$((client_index + 1))
        elif [ $field_index -lt $WLAN_CLIENT_TABLE_FIELD_COUNT ]; then
            client_index=1
            field_index=$((field_index + 1))
        fi
        echo $OID_WLAN_CLIENT_ENTRY.$field_index.$client_index
    fi
}

find_next() {
    local oid=$1
    case $oid in
        $OID_WLAN_INTERFACES| \
        $OID_WLAN_INTERFACE_COUNT) echo $OID_WLAN_INTERFACE_COUNT.0;;

        $OID_WLAN_INTERFACE_COUNT.0| \
        $OID_WLAN_INTERFACE_TABLE| \
        $OID_WLAN_INTERFACE_TABLE.1| \
        $OID_WLAN_INTERFACE_ENTRY| \
        $OID_WLAN_INTERFACE_ENTRY.1) echo $OID_WLAN_INTERFACE_ENTRY.1.1;;

        $OID_WLAN_INTERFACE_ENTRY.*) find_next_interface $oid;;

        $OID_WLAN_CLIENTS| \
        $OID_WLAN_CLIENT_COUNT) echo $OID_WLAN_CLIENT_COUNT.0;;

        $OID_WLAN_CLIENT_COUNT.0| \
        $OID_WLAN_CLIENT_TABLE| \
        $OID_WLAN_CLIENT_TABLE.1| \
        $OID_WLAN_CLIENT_ENTRY| \
        $OID_WLAN_CLIENT_ENTRY.1) echo $OID_WLAN_CLIENT_ENTRY.1.1;;

        $OID_WLAN_CLIENT_ENTRY.*) find_next_client $oid;;

        $OID_ROOT| \
        $OID_NETWORK_ROOT| \
        $OID_WLAN_ROOT| \
        $OID_WLAN_INTERFACES) echo $OID_WLAN_INTERFACE_COUNT.0;;
    esac
}

dispatch_interfaces_count() {
    echo $oid
    echo counter
    echo $ALL_WLAN_IFACES | tr ' ' '\n' | wc -l
}

# dispatch_oid_interfaces() {
#     local cmd=$1
#     local oid=$2

#     if [[ ! "$oid" =~ "$OID_WLAN_INTERFACE_ENTRY.*" ]]; then
#         return
#     fi

#     # local iface_index=$(get_oid_part $oid -2)
#     # local field_index=$(get_oid_part $oid -1)
#     local rest=${oid#$OID_WLAN_INTERFACE_ENTRY.}
#     local field_index=$(get_oid_part $rest 1)
#     local iface_index=$(get_oid_part $rest 2)

#     if [ -z "$iface_index" -o -z "$field_index" ]; then
#         return
#     fi

#     local record=$(get_interfaces_info | awk "NR==$iface_index { print; exit; }")
#     if [ -z $record ]; then
#         return
#     fi

#     local type=$(echo $WLAN_INTERFACE_TABLE_SNMP_PASS_TYPES | cut -d "," -f $field_index)
#     local data=$(get_record_part $record $field_index)
#     if [ -n $oid -a -n $type -a -n $data ]; then
#         echo $oid
#         echo $type
#         echo $data
#     fi
# }

dispatch_oid_interfaces() {
    local cmd=$1
    local oid=$2
    local field_index=$(get_oid_part $oid -2)
    local iface_index=$(get_oid_part $oid -1)

    local record=$(get_interfaces_info | awk "NR==$iface_index { print; exit; }")
    if [ -z $record ]; then
        return
    fi

    local type=$(echo $WLAN_INTERFACE_TABLE_SNMP_PASS_TYPES | cut -d "," -f $field_index)
    local data=$(get_record_part $record $field_index)
    if [ -n $oid -a -n $type -a -n $data ]; then
        echo $oid
        echo $type
        echo $data
    fi
}

dispatch_clients_count() {
    refresh_client_cache_if_needed

    echo $oid
    echo counter
    cat $CLIENTS_CACHE_FILE | wc -l
}

dispatch_oid_clients() {
    local cmd=$1
    local oid=$2
    local field_index=$(get_oid_part $oid -2)
    local client_index=$(get_oid_part $oid -1)

    # Cache clients (if needed) when attempting to retrieve the first property (index 1) of the
    # first client (client_index 1). This way we'll end up with a consistent view across the
    # whole client enumeration.
    if [ $client_index -eq 1 -a $field_index -eq 1 ]; then
        refresh_client_cache_if_needed
    fi

    local record=$(awk "NR==$client_index { print; exit; }" $CLIENTS_CACHE_FILE)
    if [ -z $record ]; then
        return
    fi

    local type=$(echo $WLAN_CLIENT_TABLE_SNMP_PASS_TYPES | cut -d "," -f $field_index)
    local data=$(get_record_part $record $field_index)
    if [ -n $oid -a -n $type -a -n $data ]; then
        echo $oid
        echo $type
        echo $data
    fi
}

dispatch_oid() {
    local cmd=$1
    local oid=$2
    case $oid in
        $OID_WLAN_INTERFACE_COUNT.0) dispatch_interfaces_count $*;;

        $OID_WLAN_INTERFACE_TABLE| \
        $OID_WLAN_INTERFACE_TABLE.*) dispatch_oid_interfaces $*;;

        $OID_WLAN_CLIENT_COUNT.0) dispatch_clients_count $*;;

        $OID_WLAN_CLIENT_TABLE| \
        $OID_WLAN_CLIENT_TABLE.*) dispatch_oid_clients $*;;
    esac
}

echo $$ > $PID_FILE
echo "$0 $*" >> $LOG_FILE

cmd="$1"
oid="$2"

# Prevent any SET requests
if [ "$cmd" = "-s" ]; then
    echo not-writable
    exit 0
fi

# Option -x just executes the find_next call.
# It's used just for debugging (it's not used by NetSNMP)
if [ "$cmd" = "-n" -o "$cmd" = "-x" ]; then
    oid=$(find_next $oid)

    if [ "$cmd" = "-x" ]; then
        echo $oid
        exit 0
    fi
fi

(dispatch_oid $cmd $oid 2>> $LOG_FILE) | tee -a $LOG_FILE
exit 0
