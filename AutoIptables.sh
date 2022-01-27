#!/usr/bin/env bash
IOT_INTERFACE=eth0.3
OUTPUT=fwrules.txt
INPUT=iotdevices.csv
OLDIFS=$IFS
IFS=','
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
> $OUTPUT
while read device protocol port comment
do
        echo "$device $protocol $port $comment"
        echo "iptables -A FORWARD -i $IOT_INTERFACE -p $protocol --dport $port -j ACCEPT -m comment --comment $comment" >> $OUTPUT
done < $INPUT
IFS=$OLDIFS

if grep -w "Chromecast" $OUTPUT
then
        sed -i'' s/#enable-reflector=no/enable-reflector=yes/ /etc/avahi/avahi-daemon.conf
        echo "----- Chromecast added -----"
fi