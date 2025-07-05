#!/bin/bash

#================================================================================
#
#          FILE: install-aws.sh
#         USAGE: bash <(curl -sSL https://raw.githubusercontent.com/Kinglas666/my-hysteria-script/main/install-aws.sh)
#   DESCRIPTION: AWS EC2 优化版 Hysteria 2 安装脚本
#                专门针对亚马逊云服务器环境优化
#        AUTHOR: Kinglas & AI Assistant
#       VERSION: 3.1 (AWS Optimized)
#          DATE: 2025-07-06
#
#================================================================================

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# --- 日志函数 ---
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_debug() { echo -e "${PURPLE}[DEBUG]${NC} $1"; }

# --- 横幅显示 ---
show_banner() {
    echo -e "${CYAN}"
    echo "================================================="
    echo "    Hysteria 2 AWS优化版一键安装脚本 v3.1"
    echo "    专门适配亚马逊云服务器环境"
    echo "    解决认证失败和TLS握手问题"
    echo "================================================="
    echo -e "${NC}"
}

# --- 改进的错误处理 ---
set -eE
error_handler() {
    local exit_code=$?
    local line_number=$1
    log_error "脚本在第 $line_number 行发生错误 (退出代码: $exit_code)"
    
    # 显示最近的日志信息
    if [[ -f /var/log/hysteria-install.log ]]; then
        log_info "最近的安装日志:"
        tail -10 /var/log/hysteria-install.log
    fi
    
    # 清理临时文件
    cleanup_on_error
    
    log_error "安装失败，请检查上述错误信息"
    exit $exit_code
}

trap 'error_handler $LINENO' ERR

# --- 清理函数 ---
cleanup_on_error() {
    log_info "清理临时文件..."
    rm -f /tmp/hysteria
    rm -f /tmp/install.log
}

# --- 检查root权限 ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo bash <(curl -sSL https://raw.githubusercontent.com/Kinglas666/my-hysteria-script/main/install.sh)"
        exit 1
    fi
}

# --- 检查系统兼容性 (AWS优化) ---
check_system() {
    log_info "检查AWS EC2系统兼容性..."
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        log_info "检测到系统: $PRETTY_NAME"
        
        # AWS AMI特殊处理
        if [[ "$ID" == "amzn" ]]; then
            OS="amazon"
            log_info "检测到Amazon Linux，启用兼容模式"
        fi
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi
    
    # 检查架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            HYSTERIA_ARCH="amd64"
            ;;
        aarch64)
            HYSTERIA_ARCH="arm64"
            ;;
        *)
            log_error "不支持的系统架构: $ARCH"
            exit 1
            ;;
    esac
    log_info "系统架构: $ARCH -> Hysteria架构: $HYSTERIA_ARCH"
    
    # 检查是否在AWS环境
    if curl -s --connect-timeout 5 --max-time 10 http://169.254.169.254/latest/meta-data/instance-id &>/dev/null; then
        AWS_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
        log_info "检测到AWS EC2实例: $AWS_INSTANCE_ID (区域: $AWS_REGION)"
        IS_AWS=true
    else
        log_info "未检测到AWS环境，使用通用配置"
        IS_AWS=false
    fi
    
    # 检查虚拟化类型
    if command -v systemd-detect-virt &> /dev/null; then
        VIRT_TYPE=$(systemd-detect-virt)
        log_info "虚拟化类型: $VIRT_TYPE"
    fi
}

# --- 获取用户输入 ---
get_user_input() {
    log_info "请提供以下信息来配置Hysteria 2服务..."
    
    # 域名输入
    while true; do
        read -p "请输入您的域名 (例: example.com): " DOMAIN
        if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            break
        else
            log_error "请输入有效的域名格式"
        fi
    done
    
    # 密码输入
    while true; do
        read -p "请输入连接密码 (建议使用字母数字组合，8-32位): " PASSWORD
        if [[ ${#PASSWORD} -ge 8 && ${#PASSWORD} -le 32 && "$PASSWORD" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            log_error "密码必须为8-32位的字母数字组合（避免特殊字符）"
        fi
    done
    
    # 邮箱输入
    while true; do
        read -p "请输入您的邮箱 (用于ACME证书申请): " EMAIL
        if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            log_error "请输入有效的邮箱地址"
        fi
    done
    
    # 端口选择
    read -p "请输入监听端口 (默认443，回车使用默认): " PORT
    PORT=${PORT:-443}
    
    log_info "配置信息确认:"
    log_info "域名: $DOMAIN"
    log_info "密码: $PASSWORD"
    log_info "邮箱: $EMAIL"
    log_info "端口: $PORT"
    
    read -p "确认以上信息正确？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "配置取消，请重新运行脚本"
        exit 0
    fi
}

# --- 系统优化 (AWS优化) ---
optimize_system() {
    log_info "开始AWS EC2系统优化..."
    
    # 创建日志文件
    touch /var/log/hysteria-install.log
    exec 1> >(tee -a /var/log/hysteria-install.log)
    exec 2> >(tee -a /var/log/hysteria-install.log >&2)
    
    # 更新系统
    log_info "更新系统包..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y >> /var/log/hysteria-install.log 2>&1
        apt-get upgrade -y >> /var/log/hysteria-install.log 2>&1
        apt-get install -y curl wget socat cron ca-certificates openssl ntpdate >> /var/log/hysteria-install.log 2>&1
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum update -y >> /var/log/hysteria-install.log 2>&1
        yum install -y curl wget socat cronie ca-certificates openssl ntpdate >> /var/log/hysteria-install.log 2>&1
    elif [[ "$OS" == "amazon" ]]; then
        yum update -y >> /var/log/hysteria-install.log 2>&1
        yum install -y curl wget socat cronie ca-certificates openssl ntpdate >> /var/log/hysteria-install.log 2>&1
    fi
    
    # 时间同步（关键：解决CRYPTO_ERROR）
    log_info "同步系统时间..."
    if command -v timedatectl &> /dev/null; then
        timedatectl set-ntp true
        sleep 2
    fi
    
    # 使用多个时间服务器
    TIME_SERVERS=("time.cloudflare.com" "time.google.com" "pool.ntp.org" "time.aws.com")
    for server in "${TIME_SERVERS[@]}"; do
        if ntpdate -s "$server" 2>/dev/null; then
            log_info "时间同步成功: $server"
            break
        fi
    done
    
    # 设置时区
    if [[ "$IS_AWS" == true ]]; then
        timedatectl set-timezone UTC 2>/dev/null || true
    fi
    log_info "当前系统时间: $(date)"
    
    # AWS网络优化
    log_info "优化AWS网络参数..."
    cat > /tmp/aws-sysctl.conf << EOF
# AWS EC2 网络优化参数
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_congestion_control = bbr
EOF
    
    # 安全地合并到sysctl.conf
    if [[ -f /etc/sysctl.conf ]]; then
        cat /tmp/aws-sysctl.conf >> /etc/sysctl.conf
    else
        cp /tmp/aws-sysctl.conf /etc/sysctl.conf
    fi
    
    sysctl -p >/dev/null 2>&1 || true
    rm -f /tmp/aws-sysctl.conf
}

# --- 下载Hysteria 2 (增强错误处理) ---
download_hysteria() {
    log_info "下载 Hysteria 2 最新版本..."
    
    # 设置下载重试次数
    RETRY_COUNT=3
    
    # 获取最新版本
    for i in $(seq 1 $RETRY_COUNT); do
        LATEST_VERSION=$(curl -s --connect-timeout 10 --max-time 30 "https://api.github.com/repos/apernet/hysteria/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' 2>/dev/null || echo "")
        if [[ -n "$LATEST_VERSION" ]]; then
            break
        fi
        log_warning "获取版本信息失败，重试 $i/$RETRY_COUNT"
        sleep 2
    done
    
    if [[ -z "$LATEST_VERSION" ]]; then
        log_warning "无法获取最新版本，使用稳定版本 app/v2.6.1"
        LATEST_VERSION="app/v2.6.1"
    fi
    log_info "目标版本: $LATEST_VERSION"
    
    # 构建下载URL
    DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${LATEST_VERSION}/hysteria-linux-${HYSTERIA_ARCH}"
    log_debug "下载地址: $DOWNLOAD_URL"
    
    # 下载二进制文件（带重试）
    log_info "正在下载 Hysteria 2 二进制文件..."
    for i in $(seq 1 $RETRY_COUNT); do
        if curl -L --connect-timeout 30 --max-time 300 --progress-bar -o /tmp/hysteria "${DOWNLOAD_URL}"; then
            log_success "下载完成"
            break
        else
            log_warning "下载失败，重试 $i/$RETRY_COUNT"
            sleep 5
            if [[ $i -eq $RETRY_COUNT ]]; then
                log_error "下载失败，请检查网络连接或手动下载"
                exit 1
            fi
        fi
    done
    
    # 验证下载文件
    if [[ ! -f /tmp/hysteria ]] || [[ ! -s /tmp/hysteria ]]; then
        log_error "下载的文件无效或为空"
        exit 1
    fi
    
    # 安装二进制文件
    chmod +x /tmp/hysteria
    if ! mv /tmp/hysteria /usr/local/bin/hysteria; then
        log_error "安装二进制文件失败，请检查权限"
        exit 1
    fi
    log_success "Hysteria 2 安装完成"
    
    # 验证安装
    if /usr/local/bin/hysteria version >/dev/null 2>&1; then
        INSTALLED_VERSION=$(/usr/local/bin/hysteria version | head -n1)
        log_success "安装验证成功: $INSTALLED_VERSION"
    else
        log_error "安装验证失败"
        exit 1
    fi
}

# --- 创建配置文件 ---
create_config() {
    log_info "创建 Hysteria 2 配置文件..."
    
    # 创建配置目录
    mkdir -p /etc/hysteria
    mkdir -p /etc/hysteria/certs
    
    # 设置正确的权限
    chmod 755 /etc/hysteria
    chmod 755 /etc/hysteria/certs
    
    # 创建服务器配置文件（AWS优化）
    cat > /etc/hysteria/config.yaml << EOF
# Hysteria 2 服务器配置 - AWS优化版
# 针对AWS EC2环境和认证问题进行专门优化

listen: :${PORT}

# ACME自动证书配置
acme:
  domains:
    - ${DOMAIN}
  email: ${EMAIL}
  storage: /etc/hysteria/certs
  ca: letsencrypt
  listenHost: 0.0.0.0

# 认证配置
auth:
  type: password
  password: "${PASSWORD}"

# QUIC协议优化 (AWS网络优化)
quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
  maxIdleTimeout: 60s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false

# 带宽配置 (AWS网络特性)
bandwidth:
  up: 500 mbps
  down: 500 mbps

# 忽略客户端带宽设置
ignoreClientBandwidth: false

# Masquerade配置
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

# 传输优化
transport:
  udp:
    hopInterval: 30s

# 日志配置
log:
  level: info
  timestamp: true
EOF

    log_success "配置文件创建完成"
    log_debug "配置文件位置: /etc/hysteria/config.yaml"
    
    # 验证配置文件
    if [[ ! -f /etc/hysteria/config.yaml ]]; then
        log_error "配置文件创建失败"
        exit 1
    fi
}

# --- 创建systemd服务 ---
create_service() {
    log_info "创建 systemd 服务..."
    
    cat > /etc/systemd/system/hysteria-server.service << EOF
[Unit]
Description=Hysteria 2 Server Service (AWS Optimized)
Documentation=https://v2.hysteria.network/
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStartPre=/bin/mkdir -p /etc/hysteria/certs
ExecStartPre=/bin/chmod 755 /etc/hysteria/certs
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
Restart=always
RestartSec=10
RestartPreventExitStatus=23
LimitNOFILE=1048576

# 环境变量
Environment=HYSTERIA_LOG_LEVEL=info
Environment=GOMAXPROCS=4

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/hysteria

[Install]
WantedBy=multi-user.target
EOF

    # 重载并启用服务
    systemctl daemon-reload
    systemctl enable hysteria-server.service
    log_success "systemd 服务创建完成"
}

# --- 配置AWS安全组和防火墙 ---
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # AWS Security Group提示
    if [[ "$IS_AWS" == true ]]; then
        log_warning "重要提醒: 请确保在AWS控制台中配置安全组规则："
        log_warning "  - 允许入站UDP ${PORT}端口"
        log_warning "  - 允许入站TCP 80端口（用于ACME验证）"
        log_warning "  - 允许入站TCP 443端口（用于HTTPS）"
    fi
    
    # UFW配置
    if command -v ufw &> /dev/null; then
        ufw --force reset >/dev/null 2>&1 || true
        ufw default deny incoming >/dev/null 2>&1
        ufw default allow outgoing >/dev/null 2>&1
        ufw allow ssh >/dev/null 2>&1
        ufw allow ${PORT}/udp >/dev/null 2>&1
        ufw allow 80/tcp >/dev/null 2>&1
        ufw allow 443/tcp >/dev/null 2>&1
        ufw --force enable >/dev/null 2>&1
        log_success "UFW 防火墙配置完成"
    fi
    
    # iptables配置
    if command -v iptables &> /dev/null; then
        iptables -I INPUT -p udp --dport ${PORT} -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
        
        # 保存iptables规则
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "amazon" ]]; then
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
        fi
    fi
}

# --- 启动服务并测试 ---
start_and_test() {
    log_info "启动 Hysteria 2 服务..."
    
    # 启动服务
    systemctl start hysteria-server.service
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet hysteria-server.service; then
        log_success "Hysteria 2 服务启动成功"
    else
        log_error "服务启动失败，检查日志..."
        log_error "错误详情:"
        journalctl -u hysteria-server.service --no-pager -n 20
        exit 1
    fi
    
    # 检查端口监听
    log_info "检查端口监听状态..."
    sleep 3
    if ss -ulpn | grep ":${PORT}" >/dev/null 2>&1; then
        log_success "端口 ${PORT} 监听正常"
    else
        log_warning "端口监听检查异常，请检查防火墙和安全组设置"
        log_info "当前监听端口:"
        ss -ulpn | grep hysteria || true
    fi
    
    # 服务状态显示
    echo
    log_info "服务状态信息:"
    systemctl status hysteria-server.service --no-pager -l
}

# --- 生成客户端配置 ---
generate_client_config() {
    log_info "生成客户端配置..."
    
    # 获取服务器IP
    if [[ "$IS_AWS" == true ]]; then
        # AWS环境优先使用公网IP
        SERVER_IP=$(curl -s --connect-timeout 5 --max-time 10 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    fi
    
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s --connect-timeout 10 --max-time 15 ipv4.icanhazip.com || curl -s --connect-timeout 10 --max-time 15 ifconfig.me || curl -s --connect-timeout 10 --max-time 15 ipinfo.io/ip || echo "YOUR_SERVER_IP")
    fi
    
    if [[ -z "$SERVER_IP" || "$SERVER_IP" == "YOUR_SERVER_IP" ]]; then
        log_warning "无法自动获取服务器IP，请手动替换配置中的 YOUR_SERVER_IP"
    fi
    
    # 创建客户端配置目录
    mkdir -p /root/hysteria-client
    
    # 生成客户端配置
    cat > /root/hysteria-client/client.yaml << EOF
# Hysteria 2 客户端配置 (AWS优化版)
server: ${SERVER_IP}:${PORT}

auth: ${PASSWORD}

tls:
  sni: ${DOMAIN}
  ca: ""
  insecure: false

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
  maxIdleTimeout: 60s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: false

bandwidth:
  up: 100 mbps
  down: 200 mbps

socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080

transport:
  type: udp
  udp:
    hopInterval: 30s

# 快速重连
fastOpen: true
lazy: true
EOF

    # 生成连接信息
    SHARE_LINK="hysteria2://${PASSWORD}@${SERVER_IP}:${PORT}/?sni=${DOMAIN}&insecure=0#Hysteria2-AWS-Server"
    
    cat > /root/hysteria-client/connection-info.txt << EOF
=== Hysteria 2 AWS服务器连接信息 ===

服务器地址: ${SERVER_IP}
端口: ${PORT}
密码: ${PASSWORD}
域名/SNI: ${DOMAIN}
协议: Hysteria 2

=== 客户端配置文件 ===
配置文件位置: /root/hysteria-client/client.yaml

=== 分享链接 ===
${SHARE_LINK}

=== AWS特别说明 ===
1. 确保AWS安全组已开放UDP ${PORT}端口
2. 确保AWS安全组已开放TCP 80和443端口
3. 检查域名DNS解析是否正确指向AWS公网IP: ${SERVER_IP}

=== 客户端软件推荐 ===
- Windows: v2rayN, Clash Verge
- Android: NekoBox, Surfboard
- iOS: Shadowrocket, Surge
- macOS: ClashX Pro, Surge

=== 故障排查 ===
如果连接失败，请检查：
1. AWS安全组入站规则是否正确配置
2. 域名DNS解析是否正确
3. 服务器时间是否同步
4. 防火墙规则是否正确

=== 管理命令 ===
启动服务: systemctl start hysteria-server
停止服务: systemctl stop hysteria-server
重启服务: systemctl restart hysteria-server
查看状态: systemctl status hysteria-server
查看日志: journalctl -u hysteria-server -f
查看安装日志: cat /var/log/hysteria-install.log

EOF

    log_success "客户端配置生成完成"
    log_info "配置文件保存在: /root/hysteria-client/"
}

# --- 显示安装结果 ---
show_result() {
    echo
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}    Hysteria 2 AWS优化版安装完成！${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo
    echo -e "${YELLOW}服务器信息:${NC}"
    echo -e "  AWS实例ID: ${CYAN}${AWS_INSTANCE_ID:-"未知"}${NC}"
    echo -e "  AWS区域: ${CYAN}${AWS_REGION:-"未知"}${NC}"
    echo -e "  服务器IP: ${CYAN}${SERVER_IP}${NC}"
    echo -e "  监听端口: ${CYAN}${PORT}${NC}"
    echo -e "  域名: ${CYAN}${DOMAIN}${NC}"
    echo -e "  密码: ${CYAN}${PASSWORD}${NC}"
    echo
    echo -e "${YELLOW}客户端配置:${NC}"
    echo -e "  配置文件: ${CYAN}/root/hysteria-client/client.yaml${NC}"
    echo -e "  连接信息: ${CYAN}/root/hysteria-client/connection-info.txt${NC}"
    echo
    echo -e "${YELLOW}分享链接:${NC}"
    echo -e "  ${CYAN}hysteria2://${PASSWORD}@${SERVER_IP}:${PORT}/?sni=${DOMAIN}&insecure=0#Hysteria2-AWS-Server${NC}"
    echo
    echo -e "${YELLOW}AWS安全组配置检查:${NC}"
    echo -e "  ${RED}重要：${NC}请确保在AWS控制台配置以下入站规则："
    echo -e "  • UDP ${PORT} (来源: 0.0.0.0/0)"
    echo -e "  • TCP 80 (来源: 0.0.0.0/0)"
    echo -e "  • TCP 443 (来源: 0.0.0.0/0)"
    echo
    echo -e "${YELLOW}管理命令:${NC}"
    echo -e "  启动服务: ${CYAN}systemctl start hysteria-server${NC}"
    echo -e "  停止服务: ${CYAN}systemctl stop hysteria-server${NC}"
    echo -e "  重启服务: ${CYAN}systemctl restart hysteria-server${NC}"
    echo -e "  查看状态: ${CYAN}systemctl status hysteria-server${NC}"
    echo -e "  查看日志: ${CYAN}journalctl -u hysteria-server -f${NC}"
    echo -e "  查看安装日志: ${CYAN}cat /var/log/hysteria-install.log${NC}"
    echo
    echo -e "${YELLOW}重要提醒:${NC}"
    echo -e "  1. 域名DNS必须解析到AWS公网IP: ${SERVER_IP}"
    echo -e "  2. AWS安全组必须开放相应端口"
    echo -e "  3. 首次连接可能需要等待1-2分钟让证书生效"
    echo -e "  4. 如有连接问题，请检查AWS安全组和防火墙设置"
