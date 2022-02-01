#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check if script is running as root
if [ "$(id -u)" -ne 0 ];
then
    echo "ERROR! This script must be run by root"
    exit 1
fi

apt update -y

# Make sure iptables-persistent does not need user input
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

# Install needed packages
apt install vlan dnsmasq iptables-persistent -y

# Add 8021q to modules to load it in the kernel
if  grep -q "8021q" "/etc/modules" ; then
    echo "8021q module is OK"
else
sudo su -c "echo \"8021q\" >> /etc/modules"
fi
echo "----- 8021q added -----"

# Add VLANS to /etc/network/interfaces.d/vlans
if  grep -q "USER VLAN" "/etc/network/interfaces.d/vlans" ; then
    echo "/etc/network/interfaces.d/vlans is OK"
else
    tee -a /etc/network/interfaces.d/vlans <<EOF
# USER VLAN
auto eth0.2
iface eth0.2 inet manual
  vlan-raw-device eth0

# IoT VLAN
auto eth0.3
iface eth0.3 inet manual
  vlan-raw-device eth0

# WAN VLAN
auto eth0.10
iface eth0.10 inet manual
  vlan-raw-device eth0
EOF
fi
echo "----- /etc/network/interfaces.d/vlans done -----"

# Add dhcpcd configuration
if  grep -q "interface eth0.10" "/etc/dhcpcd.conf" ; then
    echo "/etc/dhcpcd.conf is OK"
else
    tee -a /etc/dhcpcd.conf <<EOF
interface eth0.10
static domain_nameservers=8.8.8.8,8.8.4.4,1.1.1.1
interface eth0.2
static domain_nameservers=1.1.1.1.1
static ip_address=192.168.2.1/24
interface eth0.3
static domain_nameservers=1.1.1.1.1
static ip_address=192.168.3.1/24
EOF
fi
echo "----- /etc/dhcpcd.conf done -----"

# Add VLAN interfaces to /etc/network/interfaces
> '/etc/network/interfaces'
tee -a /etc/network/interfaces <<EOF
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/netyork/interfaces .d:
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
post-up ifup eth0.2
post-up ifup eth0.3
post-up ifup eth0.10

# USER VLAN
iface eth0.2 inet static
address 192.168.2.1
netmask 255.255.255.0
network 192.168.2.0
broadcast 192.168.2.255

# IoT VLAN
iface eth0.3 inet static
address 192.168.3.1
netmask 255.255.255.0
network 192.168.3.0
broadcast 192.168.3.255
EOF
echo "----- /etc/network/interfaces done -----"

# Add DNSMasq config and DHCP ranges to /etc/dnsmasq.conf
> '/etc/dnsmasq.conf'
tee -a /etc/dnsmasq.conf <<EOF
# USER VLAN
interface=eth0.2
listen-address=172.0.0.1
domain=yourdomain.com
dhcp-range=192.168.2.1,192.168.2.254,12h

# USER VLAN
interface=eth0.3
listen-address=172.0.0.1
domain=yourdomain.com
dhcp-range=192.168.3.1,192.168.3.254,12h
EOF
echo "----- /etc/dnsmasq.conf done -----"

# Enable ipv4 forwarding.
sed -i'' s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/ /etc/sysctl.conf
echo "----- ipv4 forwarding done -----"

echo "----- script done -----"