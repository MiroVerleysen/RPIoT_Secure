#!/usr/bin/env bash

# USER VARIABLES
ENABLE_INTERNET=true
USER_INTERFACE=eth0.2
IOT_INTERFACE=eth0.3
WAN_INTERFACE=eth0.10
OUTPUT=fwrules.txt
INPUT=iotdevices.csv

# SYSTEM VARIABLES
OLDIFS=$IFS
IFS=','

# Exit immediately if a command exits with a non-zero status
set -e

# Check if script is running as root
if [ "$(id -u)" -ne 0 ];
then
    echo "ERROR! This script must be run by root"
    exit 1
fi

# CHECK CSV FILE
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
> $OUTPUT

# clear iptables
cleariptables () {
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -F
    iptables -t mangle -F
    iptables -F
    iptables -X
    echo "----- iptables reset -----"
}

# forward alles droppen
defaultrules () {
    cat << EOF >> $OUTPUT
iptables -t nat -A POSTROUTING -o $WAN_INTERFACE -j MASQUERADE
iptables -P FORWARD DROP
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0.3 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i eth0.3 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -i eth0.3 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -i eth0.3 -p udp --dport 123 -j ACCEPT
EOF
}

enableavahi () {
        sed -i'' s/#enable-reflector=no/enable-reflector=yes/ /etc/avahi/avahi-daemon.conf
        service avahi-daemon restart
        echo "----- Avahi Enabled -----"
}

disableavahi () {
        sed -i'' s/enable-reflector=yes/#enable-reflector=no/ /etc/avahi/avahi-daemon.conf
        service avahi-daemon restart
        echo "----- Avahi Disabled -----"
}

enableigmpproxy () {
        if  grep -q "eth0.2" "/etc/igmpproxy.conf" ; then
                echo "igmpproxy is OK"
        else
                apt install igmpproxy -y
                > '/etc/igmpproxy.conf'
                tee -a /etc/igmpproxy.conf <<EOF
##------------------------------------------------------
## Enable Quickleave mode (Sends Leave instantly)
##------------------------------------------------------
quickleave


##------------------------------------------------------
## Configuration for eth0.2 (Upstream Interface)
##------------------------------------------------------
phyint eth0.2 upstream ratelimit 0 threshold 1


##------------------------------------------------------
## Configuration for eth0.3 (Downstream Interface)
##------------------------------------------------------
phyint eth0.3 downtream ratelimit 0 threshold 1
EOF
fi
        echo "----- igmpproxy Enabled -----"
}

disableigmpproxy () {
        apt purge igmpproxy -y
        echo "----- igmpproxy Disabled -----"
}

# Clear iptables to default
cleariptables

# Add default iptables to firewall rules file
defaultrules

# Check if internet is wanted on user VLAN
if $ENABLE_INTERNET true
then
        echo "iptables -A FORWARD -i $USER_INTERFACE -j ACCEPT" >> $OUTPUT
        echo "----- internet on user vlan Enabled -----"
else
        echo "----- internet on user vlan not Enabled -----"
fi

# Read CSV file and create iptables from it
while read protocol port device comment
do
        echo "$protocol $port $device"
        echo "iptables -A FORWARD -i $IOT_INTERFACE -p $protocol --dport $port -j ACCEPT -m comment --comment $device" >> $OUTPUT
done < $INPUT
IFS=$OLDIFS

echo "----- Connection can get lost, no worries, just reconnect -----"

# Add all rules to iptables
while IFS= read -r line
do
  $line
done < "$OUTPUT"

# Check for specefic devices that need extra config
if grep -w "chromecast" $OUTPUT # || grep -w "<devicename>" $OUTPUT
then
        enableavahi
else
        disableavahi
fi

if grep -w "sonos" $OUTPUT # || grep -w "<devicename>" $OUTPUT
then
        enableigmpproxy
else
        disableigmpproxy
fi

echo "----- script done -----"