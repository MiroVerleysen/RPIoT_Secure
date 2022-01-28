#!/usr/bin/env bash
ENABLE_INTERNET=true
USER_INTERFACE=eth0.2
IOT_INTERFACE=eth0.3
WAN_INTERFACE=eth0.10
OUTPUT=fwrules.txt
INPUT=iotdevices.csv
OLDIFS=$IFS
IFS=','
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
> $OUTPUT

# Add default iptables to firewall rules file
# nat rule om te routeren via WAN_INTERFACE
echo "iptables --table nat --append POSTROUTING --out-interface $WAN_INTERFACE -j MASQUERADE" >> $OUTPUT
# forward alles droppen
echo "iptables -P FORWARD DROP" >> $OUTPUT
echo "iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT" >> $OUTPUT


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
