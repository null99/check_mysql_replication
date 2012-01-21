#!/bin/bash

# Nagios alert status
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
REPL_DIFFERENCE=1

usage1="
Description: Checks master and slave log positions as well as slave status.

Usage: $0 -H <slave_host>

NOTE: Script assumes:
 * it is run from the master server
 * ~/.my.cnf is configured with account which has privileges to SHOW MASTER STATUS and SHOW SLAVE STATUS.
"

if [ -z $1 ]
then
    echo "$usage1"
    exit $STATE_UNKNOWN
fi

while :; do
    case "$1" in
        '')
            echo $usage1
            exit $STATE_UNKNOWN
            ;;
        -h)
            echo $usage1
            exit $STATE_UNKNOWN
            ;;
        -H)
            SLAVEIP_1=$2
            shift
            ;;
        *) 
            echo "Unknown argument: $1"
            echo $usage1
            exit $STATE_UNKNOWN
            ;;
    esac
    shift

    test -n "$1" || break
done

slave_connection_check=`mysql -h $SLAVEIP_1 -e "show slave status" 2>&1`
if [[ "$slave_connection_check" = "*ERROR*" ]]
then
    echo "Error reading slave: $slave_connection_check"
    exit $STATE_UNKNOWN
fi


master_connection_check=`mysql -e "show master status" 2>&1`
if [[ "$master_connection_check" = "*ERROR*" ]]
then
    echo "Error reading master: $master_connection_check"
    exit $STATE_UNKNOWN
fi

iSlave_1_position=`mysql -h $SLAVEIP_1 -e "show slave status" | grep bin | cut -f7`
iSlave_1_status=`mysql -h $SLAVEIP_1 -e "show slave status" | grep bin | cut -f1`
iMaster_position=`mysql -e "show master status" | grep bin | cut -f2`
iDiff_1=`expr $iMaster_position - $iSlave_1_position`

if [ $iDiff_1 -gt $REPL_DIFFERENCE ]
then
    echo "CRITICAL - master log $iMaster - slave log $iSlave_1 - log positions differ by more than $CRITICAL_VALUE"
    exit $STATE_CRITICAL
elif [ "$iSlave_1_status" != "Waiting for master to send event" ]
then
    echo "CRITICAL - slave status is '$iSlave_1_status'"
    exit $STATE_CRITICAL
else
    echo "OK - log positions match ($iMaster_position = $iSlave_1_position), slave status = '$iSlave_1_status'"
    exit $STATE_OK
fi
