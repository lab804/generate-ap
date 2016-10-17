#!/bin/sh

# Font: https://frillip.com/using-your-raspberry-pi-3-as-a-wifi-access-point-with-hostapd/

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

# Configuration Files
dhcpdconf="/etc/dhcpcd.conf"
hostapdconf="/etc/hostapd/hostapd.conf"
interfaceconf="/etc/network/interfaces"
defaultinterface="wlan0"
defaultip="172.24.1.1"

# Update packages
echo -e "${YELLOW}Updating System Packages."
sudo apt-get update -y
sudo apt-get upgrade -y

# Install
echo -e "${YELLOW}Installing the necessary packages."
sudo apt-get install -y dnsmasq hostapd

# Check whether there is file:/etc/dhcpcd.conf
if [ -f "$dhcpdconf" ]; then
 echo -e "${RED}There is no file: $dhcpdconf"
 exit
fi

echo -e "${YELLOW}Disregard wlan0"
echo "denyinterfaces wlan0" >> /etc/dhcpcd.conf

# Configuring static IP
if [ -f "$interfaceconf" ]; then
 echo -e "${RED}There is no file: $interfaceconf"
 exit
fi

echo -e "${YELLOW}Configuring static IP"

sudo cat >> $interfaceconf << "EOF"
allow-hotplug $defaultinterface
iface $defaultinterface inet static
       address $defaultip
       netmask 255.255.255.0 #TODO: Create automatic
       network 172.24.1.0
       broadcast 172.24.1.255
EOF

# Comment
echo -e "${YELLOW}wpa-conf ..."
sudo sed '/wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf/#wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf' $interfaceconf

# Restart dhcpcd
echo "${YELLOW}Restart DHCPCD..."
sudo systemctl restart dhcpcd.service

echo -n "${YELLOW}Reload the configuration wlan0"
sudo ifdown wlan0; sudo ifup wlan0

if [ -f "$hostapdconf" ]; then
 echo -e "${RED}There is no file: $hostapdconf"
 exit
fi

echo -n "${YELLOW}Configuring o hostapdconf"
sudo cat >> $hostapdconf << "EOF"

# This is the name of the WiFi interface we configured above
interface=wlan0

# Use the nl80211 driver with the brcmfmac driver
driver=nl80211

# This is the name of the network
ssid=labmet


# Use the 2.4GHz band
hw_mode=g

# Use channel 6
channel=6

# Enable 802.11n
ieee80211n=1

# Enable WMM
wmm_enabled=1

# Enable 40MHz channels with 20ns guard interval
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]

# Accept all MAC addresses
macaddr_acl=0

# Use WPA authentication
auth_algs=1

# Require clients to know the network name
ignore_broadcast_ssid=0
# Use WPA2

wpa=2
# Use a pre-shared key

wpa_key_mgmt=WPA-PSK
# The network passphrase

wpa_passphrase=raspberry
# Use AES, instead of TKIP

rsn_pairwise=CCMP
EOF

echo -n "${YELLOW}Check appears to labmet network and then Ctrl + C"
sudo /usr/sbin/hostapd /etc/hostpad.conf

# backup
sudo cp /etc/default/hostapd /etc/default/hostapd.bak
sudo sed '#DAEMON_CONF="" DAEMON_CONF="/etc/hostapd/hostapd.conf" /etc/default/hostapd' $interfaceconf
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sudo cat >> /etc/dnsmasq.conf << "EOF"
interface=$defaultinterface      # Use interface wlan0
listen-address=$defaultip # Explicitly specify the address to listen on
bind-interfaces      # Bind to the interface to make sure we aren't sending                                                                                                things elsewhere
server=8.8.8.8       # Forward DNS requests to Google DNS
domain-needed        # Don't forward short names
bogus-priv           # Never forward addresses in the non-routed address spaces.
dhcp-range=172.24.1.50,172.24.1.150,12h # Assign IP addresses between 172.24.1.50 and 172.24.1.150 with a 12 hour lease time
EOF

sudo sh -c "echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf"
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
