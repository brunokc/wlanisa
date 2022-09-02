#!/bin/sh -f

PLACE=".1.3.6.1.4.1.8072.2.255"  # NET-SNMP-PASS-MIB::netSnmpPassExamples
REQ="$2"                         # Requested OID
LOG_FILE=/tmp/passtest.log

echo "$0 $*" >> $LOG_FILE

#
#  Process SET requests by simply logging the assigned value
#      Note that such "assignments" are not persistent,
#      nor is the syntax or requested value validated
#
if [ "$1" = "-s" ]; then
  echo $* >> $LOG_FILE
  exit 0
fi

#
#  GETNEXT requests - determine next valid instance
#
if [ "$1" = "-n" ]; then
  case "$REQ" in
    $PLACE|             \
    $PLACE.0|           \
    $PLACE.0.*|         \
    $PLACE.1)       RET=$PLACE.1.0 ;;     # netSnmpPassString.0

    $PLACE.1.*|         \
    $PLACE.2|           \
    $PLACE.2.0|         \
    $PLACE.2.0.*|       \
    $PLACE.2.1|         \
    $PLACE.2.1.0|       \
    $PLACE.2.1.0.*|     \
    $PLACE.2.1.1|       \
    $PLACE.2.1.1.*|     \
    $PLACE.2.1.2|       \
    $PLACE.2.1.2.0) RET=$PLACE.2.1.2.1 ;; # netSnmpPassInteger.1

    $PLACE.2.1.2.*|     \
    $PLACE.2.1.3|       \
    $PLACE.2.1.3.0) RET=$PLACE.2.1.3.1 ;; # netSnmpPassOID.1

    $PLACE.2.*|         \
    $PLACE.3)       RET=$PLACE.3.0 ;;     # netSnmpPassTimeTicks.0
    $PLACE.3.*|         \
    $PLACE.4)       RET=$PLACE.4.0 ;;     # netSnmpPassIpAddress.0
    $PLACE.4.*|         \
    $PLACE.5)       RET=$PLACE.5.0 ;;     # netSnmpPassCounter.0
    $PLACE.5.*|         \
    $PLACE.6)       RET=$PLACE.6.0 ;;     # netSnmpPassGauge.0

    *)              exit 0 ;;
  esac
else
#
#  GET requests - check for valid instance
#
  case "$REQ" in
    $PLACE.1.0|         \
    $PLACE.2.1.2.1|     \
    $PLACE.2.1.3.1|     \
    $PLACE.3.0|         \
    $PLACE.4.0|         \
    $PLACE.5.0|         \
    $PLACE.6.0)     RET=$REQ ;;
    *)              exit 0 ;;
  esac
fi

print() {
    echo $* | tee -a $LOG_FILE
}

#
#  "Process" GET* requests - return hard-coded value
#
print "$RET"
case "$RET" in
  $PLACE.1.0)     print "string";    print "Life, the Universe, and Everything"; exit 0 ;;
  $PLACE.2.1.2.1) print "integer";   print "42";                                 exit 0 ;;
  $PLACE.2.1.3.1) print "objectid";  print "$PLACE.99";                          exit 0 ;;
  $PLACE.3.0)     print "timeticks"; print "363136200";                          exit 0 ;;
  $PLACE.4.0)     print "ipaddress"; print "127.0.0.1";                          exit 0 ;;
  $PLACE.5.0)     print "counter";   print "42";                                 exit 0 ;;
  $PLACE.6.0)     print "gauge";     print "42";                                 exit 0 ;;
  *)              print "string";    print "ack... $RET $REQ";                   exit 0 ;;  # Should not happen
esac
