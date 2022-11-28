#!/bin/sh
# FILE: "check_ddm"
# DESCRIPTION: Check Dante Domain Manager status
# REQUIRES: snmpget, snmptable, MIBs from audinate
# AUTHOR: Toni Comerma
# DATE: dec-2022


BASEOID=.1.3.6.1.4.1.31682.3.2
ddmVersion=$BASEOID.3.1.1.0
ddmLicense=$BASEOID.3.2.1.0
ddmTLSExpiry=$BASEOID.3.3.2.0

ddmMgrStatus=$BASEOID.4.1.1.0
  #	running(1),
  #	error(2),
  # inactive(3)
ddmDiscoveryStatus=$BASEOID.4.1.2.0
  #	running(1),
  #	error(2),
  # inactive(3)

ddmSMTPStatus=$BASEOID.4.2.1.0
  #	running(1),
  #	error(2),
  # inactive(3)

ddmLDAPtatus=$BASEOID.4.2.2.0
  #	running(1),
  #	error(2),
  # inactive(3)

# HA
ddmHATable=$BASEOID.4.1.3.2

# DOMAINS
ddmDOMAINSTable=$BASEOID.5.1

# Functions

get_info () {
    # Get version number
    VERSION=`snmpget -v 2c -c $COMMUNITY -On $HOST $ddmVersion 2>&1`
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Error connecting $HOST. $VERSION"
        exit $STATE_CRITICAL
    fi
 
    VERSION=`echo $VERSION | cut -f2 -d '=' | cut -f2 -d ":" | cut -f2- -d " "`
 
    # Get License
    LICENSE=`snmpget -v 2c -c $COMMUNITY -Oq $HOST $ddmLicense 2>&1`
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Error connecting $HOST. $LICENSE"
        exit $STATE_CRITICAL
    fi
    LICENSE=`echo $LICENSE | cut -f2 -d ' ' | tr -d '"'`
    VERSION="Version: $VERSION-$LICENSE"
}

num_to_status () {
    case "$1" in
       1) echo "running"
          ;;
       2) echo "error"
          ;;
       3) echo "inactive"
          ;;
    esac
}

check_system () {
    # Get DDM Status
    SYS=`snmpget -v 2c -c $COMMUNITY -On -Oe $HOST $ddmMgrStatus 2>&1`
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Error connecting $HOST. $SYS"
        exit $STATE_CRITICAL
    fi
    SYS=`echo $SYS | cut -f2 -d '=' | cut -f2 -d ":" | cut -f2- -d " "`
    STATUS="$STATUS [Manager:`num_to_status $SYS`]"
    if [ "`num_to_status $SYS`" == "error" ]
    then
       ERROR="$ERROR ERROR:Problem with Manager"
       STATE=$STATE_CRITICAL
       PERF="$PERF Manager=0,"
    else
       PERF="$PERF Manager=1,"
    fi

    # Get Discovery Status
    SYS=`snmpget -v 2c -c $COMMUNITY -On -Oe $HOST $ddmDiscoveryStatus 2>&1`
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Error connecting $HOST. $SYS"
        exit $STATE_CRITICAL
    fi
    SYS=`echo $SYS | cut -f2 -d '=' | cut -f2 -d ":" | cut -f2- -d " "`
    STATUS="$STATUS [Discovery:`num_to_status $SYS`]"
    if [ "`num_to_status $SYS`" == "error" ]
    then
       ERROR="$ERROR ERROR:Problem with Discovery"
       STATE=$STATE_CRITICAL
       PERF="$PERF Discovery=0,"
    else
       PERF="$PERF Discovery=1,"
    fi

    # Get SMTP Status
    SYS=`snmpget -v 2c -c $COMMUNITY -On -Oe $HOST $ddmSMTPStatus 2>&1`
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Error connecting $HOST. $SYS"
        exit $STATE_CRITICAL
    fi
    SYS=`echo $SYS | cut -f2 -d '=' | cut -f2 -d ":" | cut -f2- -d " "`
    STATUS="$STATUS [SMTP:`num_to_status $SYS`]"
    if [ "`num_to_status $SYS`" == "error" ]
    then
       ERROR="$ERROR ERROR:Problem with SMTP Module"
       STATE=$STATE_CRITICAL
       PERF="$PERF SMTP=0,"
    else
       PERF="$PERF SMTP=1,"
    fi

    # Get LDAP Status
    SYS=`snmpget -v 2c -c $COMMUNITY -On -Oe $HOST $ddmLDAPtatus 2>&1`
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Error connecting $HOST. $SYS"
        exit $STATE_CRITICAL
    fi
    SYS=`echo $SYS | cut -f2 -d '=' | cut -f2 -d ":" | cut -f2- -d " "`
    STATUS="$STATUS [LDAP:`num_to_status $SYS`]"
    if [ "`num_to_status $SYS`" == "error" ]
    then
       ERROR="$ERROR ERROR:Problem with LDAP  Module"
       STATE=$STATE_CRITICAL
       PERF="$PERF LDAP=0,"
    else
       PERF="$PERF LDAP=1,"
    fi

    if [ $STATE -eq $STATE_CRITICAL ]
    then
        echo "CRITICAL: $ERRROR, $STATUS | $PERF"
        exit $STATE_CRITICAL
    fi

    echo "OK: $STATUS | $PERF"
    exit $STATE_OK
}


check_HA () {
    local NAME
    local ROLE
    local ST
    # Get HA Status
    SYS=`snmptable -v 2c -c $COMMUNITY -Cf "," -CH  $HOST $ddmHATable 2>&1`
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Error connecting $HOST. $SYS"
        exit $STATE_CRITICAL
    fi
    for s in $SYS
    do
       NAME=`echo $s | cut -f 2 -d "," | tr -d '"'`
       ROLE=`echo $s | cut -f 3 -d "," | tr -d '"'`
       ST=`echo $s | cut -f 4 -d "," | tr -d '"'`
       if [ "$ST" != "healthy" ]
       then
         STATE=$STATE_WARNING
         # Just a warning, because if SNMP is answering, means at least 1 device is running
         PERF="$PERF $ROLE=0,"
       fi
       STATUS="$STATUS [$ROLE $NAME $ST]"
       PERF="$PERF $ROLE=1,"
    done
    if [ $STATE -eq $STATE_WARNING ]
    then
        echo "WARNING: $STATUS"
        exit $STATE_WARNING
    fi
    echo "OK: $STATUS | $PERF"
    exit $STATE_OK
}

set_error_domain () {
    local ITEM=$1
    local NUM=$2
    local ST=$3
    if [ $NUM -ne 0 ]
    then
        STATUS="$STATUS [$NUM $ITEM error]"
        STATE=$STATE_CRITICAL
        ERROR="CRITICAL"
    fi 
    PERF="$PERF ${ITEM}_ERROR=$NUM,"
}

set_warning_domain () {
    local ITEM=$1
    local NUM=$2
    local ST=$3
    if [ $NUM -ne 0 ]
    then
        STATUS="$STATUS [$NUM $ITEM warning]"
        STATE=$STATE_WARNING
        ERROR="WARNING"
    fi 
    PERF="$PERF ${ITEM}_WARNING=$NUM,"
}
check_domain () {
    local DOMAIN=$1
    local NAME
    local NUM_DEVICES
 
     # Get DOMAINS
    DOM=`snmptable -v 2c -c $COMMUNITY -Cf "," -CH  $HOST $ddmDOMAINSTable 2>&1`
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Error connecting $HOST. $SYS"
        exit $STATE_CRITICAL
    fi
    for d in $DOM
    do
       NAME=`echo $d | cut -f 2 -d "," | tr -d '"'`
       NUM_DEVICES=`echo $d | cut -f 3 -d "," | tr -d '"'`
       NUM_OFFLINE=`echo $d | cut -f 4 -d "," | tr -d '"'`
       NUM_LatERR=`echo $d | cut -f 6 -d "," | tr -d '"'`
       NUM_LatWAR=`echo $d | cut -f 7 -d "," | tr -d '"'`
       NUM_ClkERR=`echo $d | cut -f 8 -d "," | tr -d '"'`
       NUM_ClkWAR=`echo $d | cut -f 9 -d "," | tr -d '"'`
       NUM_SubERR=`echo $d | cut -f 10 -d "," | tr -d '"'`
       NUM_SubWAR=`echo $d | cut -f 11 -d "," | tr -d '"'`
       NUM_ONLINE=$(( NUM_DEVICES-NUM_OFFLINE ))

       if [ "$NAME" == "$DOMAIN" ]
       then
          STATUS="$STATUS, DOMAIN $DOMAIN ($NUM_DEVICES devices/$NUM_ONLINE On/$NUM_OFFLINE Off)" 
          # Check all error counters
          set_warning_domain "Clock" $NUM_ClkWAR "$STATUS"
          set_warning_domain "Latency" $NUM_LatWAR "$STATUS"
          set_warning_domain "Subscription" $NUM_SubWAR "$STATUS"
          # Check all error counters
          set_error_domain "Clock" $NUM_ClkERR "$STATUS"
          set_error_domain "Latency" $NUM_LatERR "$STATUS"
          set_error_domain "Subscription" $NUM_SubERR "$STATUS"
          break
       fi
    done
    if [ "$NAME" != "$DOMAIN" ]
    then
        echo "UNKNOWN: $STATUS, Domain $DOMAIN not found"
        exit $STATE_UNKNOWN
    fi
    echo "$ERROR: $STATUS|$PERF"
    exit $STATE
}

# ========================================================
# MAIN PROGRAM
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
HA=""
SYSTEM=""
DOMAIN=""
STATE=$STATE_OK
STATUS=""
ERROR="OK"

SCRIPT_DIR="$( dirname -- "${BASH_SOURCE[0]}"; )";
SCRIPT_DIR="$( realpath -e -- "$SCRIPT_DIR"; )";
MIBS=+Audinate-MIB:DanteDomain-MIB
MIBDIRS=+$SCRIPT_DIR

print_usage() {
	echo "Usage: $0 -H host -C community [ -s | -h | -d DOMAIN ]"
    echo "  -s : System status"
    echo "  -h : High Availability status"
    echo "  -d DOMAIN: Domain status"
	exit $STATE_UNKNOWN
}

if test "$1" = -h; then
	print_usage
fi

IGNORE_WARNING=0
while getopts "H:C:shd:" o; do
	case "$o" in
	H )
		HOST="$OPTARG"
		;;
	C )
		COMMUNITY="$OPTARG"
		;;
    s ) SYSTEM="YES"
        ;;
    h ) HA="YES"
        ;;
    d ) DOMAIN="$OPTARG"
        ;;
     
	* )
		print_usage
		;;
	esac
done

# Parameter verification
# Check community
if [ -z "$COMMUNITY" ] ; then
    echo "ERROR: Must specify -C "
    print_usage
fi


# Get Information
get_info
STATUS="$VERSION"

# Check System
if [ "$SYSTEM" == "YES" ] ; then
    check_system
fi

# Check HA
if [ "$HA" == "YES" ] ; then
    check_HA
fi

# Check DOMAIN
if [ ! -z "$DOMAIN" ] ; then
    check_domain $DOMAIN
fi

echo "OK: $STATUS | $PERF"
exit $STATE_OK
