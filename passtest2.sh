#!/bin/sh

OID_ROOT=".1.3.6.1.4.1.9998"
OID_COUNT=".1.3.6.1.4.1.9998.2.10.1.1"
OID_TABLE=".1.3.6.1.4.1.9998.2.10.1.2"
OID_ENTRY=".1.3.6.1.4.1.9998.2.10.1.2.1"

echo $$ > /tmp/passtest2.pid

cmd=$1
oid="$2"
next_oid=$oid

if [ "$cmd" = "-n" ]; then
    case $oid in
        $OID_COUNT.0) next_oid=$OID_ENTRY.1.1;;

        $OID_ENTRY.1.1) next_oid=$OID_ENTRY.1.2;;
        $OID_ENTRY.1.2) next_oid=$OID_ENTRY.2.1;;
        $OID_ENTRY.2.1) next_oid=$OID_ENTRY.2.2;;

        $OID_ROOT|\
        $OID_ROOT.*) next_oid=$OID_COUNT.0;;
    esac
else
    case $oid in
        $OID_COUNT.0|\
        $OID_ENTRY.1.1|\
        $OID_ENTRY.1.2|\
        $OID_ENTRY.2.1|\
        $OID_ENTRY.2.2) : ;;
        *) exit 0;;
    esac
fi

echo $next_oid
case $oid in
    $OID_COUNT.0) echo "integer"; echo "2";;

    $OID_ENTRY.1.1) echo "integer"; echo "1";;
    $OID_ENTRY.1.2) echo "integer"; echo "2";;
    $OID_ENTRY.2.1) echo "string"; echo "p1";;
    $OID_ENTRY.2.2) echo "string"; echo "p2";;
esac

exit 0
