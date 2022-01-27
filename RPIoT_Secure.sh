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
sudo su -c "echo \"8021q\" >> /etc/modules"

echo "8021q added"

tee -a /etc/dhcpcd.conf <<EOF
interface eth0.10
static domain_nameservers=8.8.8.8,8.8.4.4,1.1.1.1.1
interface eth0.2
static domain_nameservers=1.1.1.1.1
static ip_address=192.168.2.1/24
interface eth0.3
static domain_nameservers=1.1.1.1.1
static ip_address=192.168.3.1/24
EOF


echo "script done"

sudo su -c "echo > /RPIoT_Secure.sh"