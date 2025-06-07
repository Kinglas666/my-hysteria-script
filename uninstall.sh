#!/bin/bash

#================================================================
#
#          FILE: uninstall_hysteria.sh
#
#         USAGE: bash uninstall_hysteria.sh
#
#   DESCRIPTION: Uninstalls Hysteria 2 completely.
#
#================================================================

echo "This script will stop and remove Hysteria 2 and its configuration."
read -p "Are you sure you want to continue? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo "Stopping Hysteria 2 service..."
systemctl stop hysteria-server.service || echo "Service was not running."

echo "Disabling Hysteria 2 service from auto-start..."
systemctl disable hysteria-server.service || echo "Service was not enabled."

echo "Removing systemd service file..."
rm -f /etc/systemd/system/hysteria-server.service

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Removing Hysteria 2 binary..."
rm -f /usr/local/bin/hysteria

echo "Removing Hysteria 2 configuration directory..."
rm -rf /etc/hysteria

echo "Hysteria 2 has been uninstalled successfully."
