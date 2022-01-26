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

echo "script done"