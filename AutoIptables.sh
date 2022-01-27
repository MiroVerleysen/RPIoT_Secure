#!/usr/bin/env bash
IOT_INTERFACE=eth0.3
OUTPUT=fwrules.txt
INPUT=iotdevices.csv
OLDIFS=$IFS
IFS=','
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
> $OUTPUT
while read protocol port device comment
do
        echo "$protocol $port $device"
        echo "iptables -A FORWARD -i $IOT_INTERFACE -p $protocol --dport $port -j ACCEPT -m comment --comment $device" >> $OUTPUT
done < $INPUT
IFS=$OLDIFS

if grep -w "chromecast" $OUTPUT
then
        sed -i'' s/#enable-reflector=no/enable-reflector=yes/ /etc/avahi/avahi-daemon.conf
        service avahi-daemon restart
        echo "----- Avahi Enabled -----"
else
        sed -i'' s/enable-reflector=yes/#enable-reflector=no/ /etc/avahi/avahi-daemon.conf
        service avahi-daemon restart
        echo "----- Avahi Disabled -----"
fi