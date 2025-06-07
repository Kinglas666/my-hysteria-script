#!/bin/bash

#================================================================================
#
#          FILE: install_hysteria_definitive_v2.sh
#
#   DESCRIPTION: The Truly Definitive Hysteria 2 Installer, using curl
#                for robust downloading and a specific stable version.
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
trap 'log_error "An error occurred at line $LINENO. Aborting."; exit 1' ERR

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

# 3. Full System Upgrade & Dependency Installation
log_info "Performing full system update, upgrade, and installing dependencies..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget socat ca-certificates
log_success "System updated and dependencies installed."

# 4. Download Hysteria 2 STABLE version (v2.6.1) using cURL
HYSTERIA_VERSION="v2.6.1"
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH_TAG="amd64" ;;
    aarch64) ARCH_TAG="arm64" ;;
    *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac
DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${HYSTERIA_VERSION}/hysteria-linux-${ARCH_TAG}"

log_info "Downloading Hysteria 2 STABLE version ${HYSTERIA_VERSION} with cURL..."
# Use curl instead of wget for better reliability with redirects
if curl -L -o /usr/local/bin/hysteria "$DOWNLOAD_URL"; then
    log_success "Download successful."
else
    log_error "Download failed. Please check network or URL."
    exit 1
fi
chmod +x /usr/local/bin/hysteria
log_success "Hysteria 2 binary (v2.6.1) installed."

# 5. Create Configuration File
log_info "Creating configuration file..."
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

# 6. Create Systemd Service
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

# 7. Start and Enable Service
log_info "Reloading systemd, enabling and starting Hysteria 2 service..."
systemctl daemon-reload
systemctl enable hysteria-server.service
systemctl start hysteria-server.service
log_success "Hysteria 2 service started and enabled."

# 8. Final Check and Instructions
sleep 2
systemctl status hysteria-server.service --no-pager
log_success "Installation of Hysteria 2 v2.6.1 is complete! Please check the status above."
log_warning "Firewall is not configured. Please manually allow TCP 80, UDP 443, and your SSH port."
