#!/bin/bash

#================================================================================
#
#          FILE: install_hysteria_final.sh
#
#         USAGE: bash install_hysteria_final.sh
#
#   DESCRIPTION: The definitive, robust, and safe Hysteria 2 installer.
#                It performs full system upgrades and ensures a stable environment.
#
#================================================================================

# --- Colors and Marks for Logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[1;94m'
NC='\033[0m'

# --- Function Definitions ---
log_info() { echo -e "${BLUE}[i] ${1}${NC}"; }
log_success() { echo -e "${GREEN}[✓] ${1}${NC}"; }
log_warning() { echo -e "${YELLOW}[!] ${1}${NC}"; }
log_error() { echo -e "${RED}[✗] ${1}${NC}" >&2; }

# --- Main Script ---
trap 'log_error "An error occurred. Aborting installation."; exit 1' ERR

log_info "Starting Hysteria 2 Definitive Installation..."

# 1. Check for Root Access
if [ "$(id -u)" -ne 0 ]; then
   log_error "This script must be run as root."
   exit 1
fi

# 2. Get User Input
read -p "Enter your domain name (e.g., your.domain.com): " DOMAIN
read -p "Enter a simple password (letters/numbers only): " PASSWORD
read -p "Enter your email for Let's Encrypt: " EMAIL
if [ -z "$DOMAIN" ] || [ -z "$PASSWORD" ] || [ -z "$EMAIL" ]; then
    log_error "Domain, password, and email cannot be empty."
    exit 1
fi

# 3. Full System Upgrade (Crucial Step)
log_info "Performing full system update and upgrade. This may take a few minutes..."
apt-get update -y
apt-get upgrade -y
log_success "System packages updated and upgraded."

# 4. Install Essential Packages
log_info "Installing essential packages: curl, wget, socat, ntpdate, ca-certificates..."
apt-get install -y curl wget socat ntpdate ca-certificates
log_success "Essential packages installed."

# 5. Sync System Time
log_info "Synchronizing system time with time.cloudflare.com..."
ntpdate time.cloudflare.com
log_success "System time synchronized."

# 6. Download Hysteria 2
HYSTERIA_VERSION=$(curl -s "https://api.github.com/repos/apernet/hysteria/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH_TAG="amd64" ;;
    aarch64) ARCH_TAG="arm64" ;;
    *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac
DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${HYSTERIA_VERSION}/hysteria-linux-${ARCH_TAG}"

log_info "Downloading Hysteria 2 version ${HYSTERIA_VERSION} for ${ARCH_TAG}..."
wget -O /usr/local/bin/hysteria "$DOWNLOAD_URL"
chmod +x /usr/local/bin/hysteria
log_success "Hysteria 2 binary installed."

# 7. Create Configuration File
log_info "Creating configuration file at /etc/hysteria/config.yaml..."
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
log_success "Configuration file created."

# 8. Create Systemd Service
log_info "Creating systemd service file..."
cat <<EOF > /etc/systemd/system/hysteria-server.service
[Unit]
Description=Hysteria 2 Service
After=network.target nss-lookup.target

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
log_success "Systemd service file created."

# 9. Start and Enable Service
log_info "Reloading systemd, enabling and starting Hysteria 2 service..."
systemctl daemon-reload
systemctl enable hysteria-server.service
systemctl start hysteria-server.service
log_success "Hysteria 2 service started and enabled."

# 10. Final Check and Instructions
sleep 2
systemctl status hysteria-server.service --no-pager
log_success "Installation complete! Please check the status above."
log_info "Now, please configure your firewall to allow TCP 80 and UDP 443."
