#!/bin/bash

# This script will disable the built-in wifi AP and
# enable wpa_supplicant and dhcpcd. If you have not configured
# wpa_supplicant beforehand, running this may make it impossible
# to connect to the TurboPi via a direct WiFi connection.

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

# disable hiwonder wifi AP
echo "Disabling the hw_wifi service (provides direct wifi AP/hotspot connection to TurboPi)"
echo Can be temporarily re-enabled with start_ap.sh
sudo systemctl disable hw_wifi

echo Setting wpa_supplicant and dhcpcd to start on boot and starting services.
sudo systemctl enable wpa_supplicant
sudo systemctl enable dhcpcd

sudo systemctl restart wpa_supplicant
sudo systemctl restart dhcpcd
echo Done.
