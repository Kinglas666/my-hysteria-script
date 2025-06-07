#!/bin/bash

#================================================================================
#
#          FILE: install_hysteria_v2.sh
#
#         USAGE: bash install_hysteria_v2.sh
#
#   DESCRIPTION: A safe and transparent script to install Hysteria 2 (Version 2).
#                It interactively asks for all necessary info, including email.
#
#================================================================================

# Set script to exit immediately if any command fails
set -e

# --- Function Definitions ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
            PKG_MANAGER="apt-get"
        elif [ "$ID" = "centos" ] || [ "$ID" = "fedora" ] || [ "$ID" = "rhel" ]; then
            PKG_MANAGER="yum"
        else
            echo "Unsupported operating system: $OS"
            exit 1
        fi
    else
        echo "Cannot detect operating system."
        exit 1
    fi
}

# --- Main Script ---

# 1. Check for Root Access
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Please use sudo or log in as root." 1>&2
   exit 1
fi

# 2. Get User Input First
read -p "Please enter your domain name (e.g., your.domain.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "Domain name cannot be empty."
    exit 1
fi

read -p "Please enter the password for Hysteria 2 connection: " PASSWORD
if [ -z "$PASSWORD" ]; then
    echo "Password cannot be empty."
    exit 1
fi

read -p "Please enter your email for Let's Encrypt certificate: " EMAIL
if [ -z "$EMAIL" ]; then
    echo "Email cannot be empty."
    exit 1
fi

# 3. Detect OS and set package manager
detect_os
echo "Detected OS: $OS, Package Manager: $PKG_MANAGER"

# 4. Install Dependencies
echo "Updating package list and installing dependencies (curl, wget, socat)..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
    $PKG_MANAGER update -y
    $PKG_MANAGER install -y curl wget socat
elif [ "$PKG_MANAGER" = "yum" ]; then
    $PKG_MANAGER install -y curl wget socat
fi
echo "Dependencies installed."

# 5. Get latest Hysteria version and download URL
echo "Fetching latest Hysteria 2 version..."
LATEST_VERSION=$(curl -s "https://api.github.com/repos/apernet/hysteria/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch latest version tag."
    exit 1
fi
echo "Latest version is: $LATEST_VERSION"

ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH_TAG="amd64" ;;
    aarch64) ARCH_TAG="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac
DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${LATEST_VERSION}/hysteria-linux-${ARCH_TAG}"

# 6. Download and Install Hysteria
echo "Downloading Hysteria binary from official source..."
wget -O /usr/local/bin/hysteria "$DOWNLOAD_URL"
chmod +x /usr/local/bin/hysteria
echo "Hysteria binary installed in /usr/local/bin/hysteria"

# 7. Create Configuration Directory and File
echo "Creating configuration directory and file..."
mkdir -p /etc/hysteria

cat <<EOF > /etc/hysteria/config.yaml
listen: :443

acme:
  domains:
    - $DOMAIN
  email: $EMAIL

auth:
  type: password
  password: $PASSWORD
EOF
echo "Configuration file created at /etc/hysteria/config.yaml"

# 8. Create systemd Service File
echo "Creating systemd service file..."
cat <<EOF > /etc/systemd/system/hysteria-server.service
[Unit]
Description=Hysteria 2 Service (Server)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
User=root
Group=root
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
echo "Systemd service file created at /etc/systemd/system/hysteria-server.service"

# 9. Start and Enable Service
echo "Reloading systemd, enabling and starting Hysteria 2 service..."
systemctl daemon-reload
systemctl enable hysteria-server.service
systemctl start hysteria-server.service

# 10. Check Service Status and Final Output
sleep 2
systemctl status hysteria-server.service --no-pager

echo ""
echo "=================================================================="
echo " Hysteria 2 Installation Complete!"
echo "=================================================================="
echo " Your Domain: $DOMAIN"
echo " Your Port: 443"
echo " Your Connection Password: $PASSWORD"
echo " Your Email: $EMAIL"
echo ""
echo " You can use 'systemctl status hysteria-server.service' to check the status."
echo "=================================================================="
