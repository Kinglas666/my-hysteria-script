#!/bin/bash

#================================================================================
#
#          FILE: install.sh
#         USAGE: bash <(curl -sSL https://raw.githubusercontent.com/Kinglas666/my-hysteria-script/main/install.sh)
#   DESCRIPTION: Optimized Hysteria 2 installer with enhanced error handling
#                Specifically designed to solve authentication and TLS issues
#        AUTHOR: Kinglas & AI Assistant
#       VERSION: 3.0 (Optimized)
#          DATE: 2025-06-07
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
    echo "    Hysteria 2 优化版一键安装脚本 v3.0"
    echo "    专门解决认证失败和TLS握手问题"
    echo "    适配 RackNerd KVM VPS 环境"
    echo "================================================="
    echo -e "${NC}"
}

# --- 错误处理 ---
set -eE
trap 'log_error "脚本在第 $LINENO 行发生错误，正在退出..."; exit 1' ERR

# --- 检查root权限 ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo bash <(curl -sSL https://raw.githubusercontent.com/Kinglas666/my-hysteria-script/main/install.sh)"
        exit 1
    fi
}

# --- 检查系统兼容性 ---
check_system() {
    log_info "检查系统兼容性..."
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        log_info "检测到系统: $PRETTY_NAME"
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
    
    # 检查虚拟化类型
    if command -v systemd-detect-virt &> /dev/null; then
        VIRT_TYPE=$(systemd-detect-virt)
        log_info "虚拟化类型: $VIRT_TYPE"
        if [[ "$VIRT_TYPE" == "kvm" ]]; then
            log_info "检测到KVM虚拟化，将启用KVM优化配置"
        fi
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
    
    # 密码输入（简化，避免特殊字符问题）
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

# --- 系统优化 ---
optimize_system() {
    log_info "开始系统优化..."
    
    # 更新系统
    log_info "更新系统包..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update -y
        apt-get upgrade -y
        apt-get install -y curl wget socat cron ca-certificates openssl
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum update -y
        yum install -y curl wget socat cronie ca-certificates openssl
    fi
    
    # 时间同步（关键：解决CRYPTO_ERROR）
    log_info "同步系统时间..."
    if command -v timedatectl &> /dev/null; then
        timedatectl set-ntp true
        sleep 2
    fi
    
    if command -v ntpdate &> /dev/null; then
        ntpdate -s time.cloudflare.com || ntpdate -s pool.ntp.org || true
    elif command -v chrony &> /dev/null; then
        systemctl restart chronyd || true
    fi
    
    # 设置时区
    timedatectl set-timezone UTC 2>/dev/null || true
    log_info "当前系统时间: $(date)"
    
    # 内核参数优化（针对KVM环境）
    log_info "优化内核参数..."
    cat >> /etc/sysctl.conf << EOF

# Hysteria 2 优化参数
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.core.netdev_max_backlog = 5000
EOF
    sysctl -p >/dev/null 2>&1 || true
}

# --- 下载Hysteria 2 ---
download_hysteria() {
    log_info "下载 Hysteria 2 最新版本..."
    
    # 获取最新版本
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/apernet/hysteria/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
    if [[ -z "$LATEST_VERSION" ]]; then
        log_warning "无法获取最新版本，使用稳定版本 app/v2.6.1"
        LATEST_VERSION="app/v2.6.1"
    fi
    log_info "目标版本: $LATEST_VERSION"
    
    # 构建下载URL
    DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${LATEST_VERSION}/hysteria-linux-${HYSTERIA_ARCH}"
    log_debug "下载地址: $DOWNLOAD_URL"
    
    # 下载二进制文件
    log_info "正在下载 Hysteria 2 二进制文件..."
    if curl -L --progress-bar -o /tmp/hysteria "${DOWNLOAD_URL}"; then
        log_success "下载完成"
    else
        log_error "下载失败，请检查网络连接"
        exit 1
    fi
    
    # 安装二进制文件
    chmod +x /tmp/hysteria
    mv /tmp/hysteria /usr/local/bin/hysteria
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
    
    # 创建服务器配置文件（关键优化）
    cat > /etc/hysteria/config.yaml << EOF
# Hysteria 2 服务器配置 - 优化版
# 针对认证失败和TLS问题进行专门优化

listen: :${PORT}

# ACME自动证书配置
acme:
  domains:
    - ${DOMAIN}
  email: ${EMAIL}
  storage: /etc/hysteria/certs
  ca: letsencrypt
  listenHost: 0.0.0.0
  

  
# 认证配置（简化以避免特殊字符问题）
auth:
  type: password
  password: "${PASSWORD}"

# 协议优化配置
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false

# 带宽和拥塞控制
bandwidth:
  up: 1000 mbps
  down: 1000 mbps

# 忽略客户端带宽设置
ignoreClientBandwidth: true

# Masquerade配置（提高隐蔽性）
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

# 禁用统计API（安全考虑）
trafficStats:
  listen: ""

# 日志配置
log:
  level: info
  timestamp: true
EOF

    log_success "配置文件创建完成"
    log_debug "配置文件位置: /etc/hysteria/config.yaml"
}

# --- 创建systemd服务 ---
create_service() {
    log_info "创建 systemd 服务..."
    
    cat > /etc/systemd/system/hysteria-server.service << EOF
[Unit]
Description=Hysteria 2 Server Service (Optimized v3.2)
Documentation=https://v2.hysteria.network/
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStartPre=/bin/mkdir -p /etc/hysteria/certs # <--- 新增此行，确保目录存在
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
Restart=always
RestartSec=5
LimitNOFILE=1048576

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/hysteria #

# 环境变量
Environment=HYSTERIA_LOG_LEVEL=info

[Install]
WantedBy=multi-user.target
EOF

    # 重载并启用服务
    systemctl daemon-reload
    systemctl enable hysteria-server.service
    log_success "systemd 服务创建完成"
}

# --- 配置防火墙 ---
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # UFW配置
    if command -v ufw &> /dev/null; then
        ufw --force reset >/dev/null 2>&1 || true
        ufw default deny incoming >/dev/null 2>&1
        ufw default allow outgoing >/dev/null 2>&1
        ufw allow ssh >/dev/null 2>&1
        ufw allow ${PORT}/udp >/dev/null 2>&1
        ufw allow 80/tcp >/dev/null 2>&1
        ufw --force enable >/dev/null 2>&1
        log_success "UFW 防火墙配置完成"
    fi
    
    # iptables备用配置
    if command -v iptables &> /dev/null; then
        iptables -I INPUT -p udp --dport ${PORT} -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
        
        # 保存iptables规则
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables.rules 2>/dev/null || true
        fi
    fi
}

# --- 启动服务并测试 ---
start_and_test() {
    log_info "启动 Hysteria 2 服务..."
    
    # 启动服务
    systemctl start hysteria-server.service
    sleep 3
    
    # 检查服务状态
    if systemctl is-active --quiet hysteria-server.service; then
        log_success "Hysteria 2 服务启动成功"
    else
        log_error "服务启动失败，检查日志..."
        journalctl -u hysteria-server.service --no-pager -n 20
        exit 1
    fi
    
    # 检查端口监听
    log_info "检查端口监听状态..."
    sleep 2
    if ss -ulpn | grep ":${PORT}" | grep hysteria >/dev/null; then
        log_success "端口 ${PORT} 监听正常"
    else
        log_warning "端口监听检查异常，请手动验证"
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
    SERVER_IP=$(curl -s ipv4.icanhazip.com || curl -s ifconfig.me || curl -s ipinfo.io/ip)
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP="YOUR_SERVER_IP"
        log_warning "无法自动获取服务器IP，请手动替换配置中的 YOUR_SERVER_IP"
    fi
    
    # 创建客户端配置目录
    mkdir -p /root/hysteria-client
    
    # 生成标准客户端配置
    cat > /root/hysteria-client/client.yaml << EOF
# Hysteria 2 客户端配置
server: ${SERVER_IP}:${PORT}

auth: ${PASSWORD}

tls:
  sni: ${DOMAIN}
  ca: ""
  insecure: false

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: false

bandwidth:
  up: 50 mbps
  down: 200 mbps

socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080

# 传输模式优化
transport:
  type: udp
  udp:
    hopInterval: 30s
EOF

    # 生成分享链接格式
    SHARE_LINK="hysteria2://${PASSWORD}@${SERVER_IP}:${PORT}/?sni=${DOMAIN}&insecure=0#Hysteria2-Server"
    
    cat > /root/hysteria-client/connection-info.txt << EOF
=== Hysteria 2 连接信息 ===

服务器地址: ${SERVER_IP}
端口: ${PORT}
密码: ${PASSWORD}
域名/SNI: ${DOMAIN}
协议: Hysteria 2

=== 客户端配置文件 ===
配置文件位置: /root/hysteria-client/client.yaml

=== 分享链接 ===
${SHARE_LINK}

=== 客户端软件推荐 ===
- Windows: v2rayN (支持Hysteria 2)
- Android: NekoBox, Surfboard
- iOS: Shadowrocket, Surge
- macOS: ClashX Pro, Surge

=== 使用说明 ===
1. 下载对应平台的客户端软件
2. 导入配置文件或使用分享链接
3. 启动客户端并连接

=== 故障排查 ===
如果连接失败，请检查：
1. 域名DNS解析是否正确指向服务器IP
2. Cloudflare代理设置（橙色云朵）
3. 服务器防火墙是否允许UDP ${PORT}端口
4. 客户端时间是否同步

EOF

    log_success "客户端配置生成完成"
    log_info "配置文件保存在: /root/hysteria-client/"
}

# --- 显示安装结果 ---
show_result() {
    echo
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}    Hysteria 2 安装完成！${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo
    echo -e "${YELLOW}服务器信息:${NC}"
    echo -e "  服务器IP: ${CYAN}$(curl -s ipv4.icanhazip.com)${NC}"
    echo -e "  监听端口: ${CYAN}${PORT}${NC}"
    echo -e "  域名: ${CYAN}${DOMAIN}${NC}"
    echo -e "  密码: ${CYAN}${PASSWORD}${NC}"
    echo
    echo -e "${YELLOW}客户端配置:${NC}"
    echo -e "  配置文件: ${CYAN}/root/hysteria-client/client.yaml${NC}"
    echo -e "  连接信息: ${CYAN}/root/hysteria-client/connection-info.txt${NC}"
    echo
    echo -e "${YELLOW}分享链接:${NC}"
    SERVER_IP=$(curl -s ipv4.icanhazip.com || echo "YOUR_SERVER_IP")
    echo -e "  ${CYAN}hysteria2://${PASSWORD}@${SERVER_IP}:${PORT}/?sni=${DOMAIN}&insecure=0#Hysteria2-Server${NC}"
    echo
    echo -e "${YELLOW}管理命令:${NC}"
    echo -e "  启动服务: ${CYAN}systemctl start hysteria-server${NC}"
    echo -e "  停止服务: ${CYAN}systemctl stop hysteria-server${NC}"
    echo -e "  重启服务: ${CYAN}systemctl restart hysteria-server${NC}"
    echo -e "  查看状态: ${CYAN}systemctl status hysteria-server${NC}"
    echo -e "  查看日志: ${CYAN}journalctl -u hysteria-server -f${NC}"
    echo
    echo -e "${YELLOW}重要提醒:${NC}"
    echo -e "  1. 请确保域名DNS正确解析到服务器IP"
    echo -e "  2. 如使用Cloudflare，请确保代理状态为'橙色云朵'"
    echo -e "  3. SSL/TLS模式建议设置为'Full (完全)'"
    echo -e "  4. 首次连接可能需要等待1-2分钟让证书生效"
    echo
    echo -e "${GREEN}============================================${NC}"
    
    # 显示连接信息文件内容
    if [[ -f /root/hysteria-client/connection-info.txt ]]; then
        echo -e "${BLUE}查看完整连接信息:${NC}"
        echo -e "${CYAN}cat /root/hysteria-client/connection-info.txt${NC}"
    fi
}

# --- 主函数 ---
main() {
    show_banner
    check_root
    check_system
    get_user_input
    optimize_system
    download_hysteria
    create_config
    create_service
    configure_firewall
    start_and_test
    generate_client_config
    show_result
    
    log_success "Hysteria 2 优化版安装完成！"
    echo
    log_info "如有问题，请查看日志: journalctl -u hysteria-server -f"
    log_info "技术支持: 请检查配置文件和防火墙设置"
}

# --- 执行主函数 ---
main "$@"
