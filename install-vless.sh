#!/bin/bash

#=================================================================================================
# VLESS-Reality 一键安装脚本 (全自动修复版)
#
# 特点:
#   - 修复了在 'curl | bash' 非交互模式下因 read 命令导致的死循环问题。
#   - 自动检测运行模式：交互模式下提示用户输入，非交互模式下自动选择随机端口。
#   - 修复了 'netstat' 命令缺失 'net-tools' 依赖的问题。
#   - 优化了 UFW 防火墙配置，避免重置用户现有规则。
#   - 增强了脚本的健壮性和错误处理。
#
# 安装命令:
# curl -fsSL https://raw.githubusercontent.com/Kinglas666/my-hysteria-script/main/install-vless.sh | bash
#=================================================================================================

# --- 配置和常量 ---
# 使用颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
NC='\033[0m' # No Color

# Xray 安装目录
INSTALL_PATH="/etc/v2ray-agent"
XRAY_PATH="${INSTALL_PATH}/xray"
XRAY_CONFIG_PATH="${XRAY_PATH}/conf"
XRAY_INFO_FILE="${INSTALL_PATH}/vless_info.txt"

# Reality 目标服务器 (可根据需要更换)
REALITY_SNI="www.microsoft.com"
REALITY_DEST_PORT=443

# --- 函数定义 ---

# 检查是否以 root 身份运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 此脚本必须以 root 权限运行。${NC}"
        echo -e "${YELLOW}请尝试使用 'sudo bash $0' 命令运行。${NC}"
        exit 1
    fi
}

# 更新系统
update_system() {
    echo -e "${SKYBLUE}---> 1. 正在更新系统软件包列表...${NC}"
    if ! apt update > /dev/null 2>&1; then
        echo -e "${RED}错误: 系统包列表更新失败。请检查您的网络或软件源配置。${NC}"
        exit 1
    fi
    echo -e "${GREEN}系统更新完成。${NC}"
}

# 安装依赖
install_prereqs() {
    echo -e "${SKYBLUE}---> 2. 正在安装必要的依赖软件...${NC}"
    # 添加 net-tools 用于 netstat 命令
    if ! apt install -y wget curl unzip ufw qrencode jq openssl net-tools > /dev/null 2>&1; then
        echo -e "${RED}错误: 依赖软件安装失败。${NC}"
        exit 1
    fi
    echo -e "${GREEN}依赖软件安装完成。${NC}"
}

# 获取端口 (兼容交互式和非交互式模式)
get_user_port() {
    # 检测是否为交互式终端
    if [ -t 0 ]; then
        # 交互模式：提示用户输入
        while true; do
            read -p "$(echo -e ${YELLOW}"请输入 VLESS 端口号 (建议范围 10000-65000，留空则随机生成): "${NC})" VLESS_PORT
            if [ -z "$VLESS_PORT" ]; then
                echo -e "${SKYBLUE}未输入端口，将为您随机生成一个。${NC}"
                break
            fi
            # 检查输入是否为数字及范围
            if [[ "$VLESS_PORT" =~ ^[0-9]+$ ]] && [ "$VLESS_PORT" -gt 1024 ] && [ "$VLESS_PORT" -le 65535 ]; then
                # 检查端口是否被占用
                if ! netstat -tuln | grep -q ":$VLESS_PORT "; then
                    break
                else
                    echo -e "${RED}端口 ${VLESS_PORT} 已被占用，请选择其他端口。${NC}"
                fi
            else
                echo -e "${RED}输入无效。请输入一个 1024-65535 之间的数字。${NC}"
            fi
        done
    else
        # 非交互模式：自动选择端口
        echo -e "${SKYBLUE}非交互模式，正在自动选择一个随机端口...${NC}"
    fi

    # 如果 VLESS_PORT 为空 (来自非交互模式或用户留空)，则随机生成
    if [ -z "$VLESS_PORT" ]; then
        while true; do
            VLESS_PORT=$((RANDOM % 55535 + 10000)) # 生成 10000-65534 之间的端口
            if ! netstat -tuln | grep -q ":$VLESS_PORT "; then
                echo -e "${GREEN}已为您随机选择端口: ${VLESS_PORT}${NC}"
                break
            fi
        done
    else
        echo -e "${GREEN}VLESS 将使用端口: ${VLESS_PORT}${NC}"
    fi
}


# 安装 Xray-core
install_xray() {
    echo -e "${SKYBLUE}---> 3. 正在安装 Xray-core...${NC}"
    mkdir -p "${XRAY_PATH}" "${XRAY_CONFIG_PATH}"
    
    ARCH=$(uname -m)
    case "$ARCH" in
        'x86_64' | 'amd64') CPU_VENDOR="Xray-linux-64" ;;
        'aarch64' | 'arm64') CPU_VENDOR="Xray-linux-arm64-v8a" ;;
        'armv7l') CPU_VENDOR="Xray-linux-arm32-v7a" ;;
        *) echo -e "${RED}错误: 不支持的CPU架构: $ARCH${NC}"; exit 1 ;;
    esac

    LATEST_VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | jq -r '.tag_name')
    if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" == "null" ]; then
        echo -e "${YELLOW}警告: 无法从 GitHub API 获取最新版本，将使用默认版本 v1.8.4${NC}"
        LATEST_VERSION="v1.8.4"
    fi
    echo -e "${GREEN}使用 Xray-core 版本: ${LATEST_VERSION}${NC}"

    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/${CPU_VENDOR}.zip"
    echo -e "${SKYBLUE}正在下载: ${DOWNLOAD_URL}${NC}"
    
    if ! wget -qO "${XRAY_PATH}/xray.zip" "${DOWNLOAD_URL}"; then
        echo -e "${RED}错误: 下载 Xray-core 失败。请检查网络或链接是否有效。${NC}"
        exit 1
    fi
    
    unzip -qo "${XRAY_PATH}/xray.zip" -d "${XRAY_PATH}"
    rm "${XRAY_PATH}/xray.zip"
    chmod +x "${XRAY_PATH}/xray"

    if [ ! -f "${XRAY_PATH}/xray" ]; then
        echo -e "${RED}错误: Xray-core 安装失败（文件不存在）。${NC}"
        exit 1
    fi
    echo -e "${GREEN}Xray-core 安装成功。${NC}"
}

# 生成 VLESS-Reality 配置文件
generate_vless_reality_config() {
    echo -e "${SKYBLUE}---> 4. 正在生成 VLESS-Reality 配置文件...${NC}"
    
    KEYS=$(${XRAY_PATH}/xray x25519)
    VLESS_UUID=$(${XRAY_PATH}/xray uuid)
    VLESS_PRIVATE_KEY=$(echo "$KEYS" | awk '/Private key:/ {print $3}')
    VLESS_PUBLIC_KEY=$(echo "$KEYS" | awk '/Public key:/ {print $3}')
    VLESS_SHORT_ID=$(openssl rand -hex 8)
    
    cat > "${XRAY_CONFIG_PATH}/config.json" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${VLESS_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${VLESS_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${REALITY_SNI}:${REALITY_DEST_PORT}",
          "xver": 0,
          "serverNames": [
            "${REALITY_SNI}"
          ],
          "privateKey": "${VLESS_PRIVATE_KEY}",
          "shortIds": [
            "${VLESS_SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "blocked" }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      { "type": "field", "protocol": ["bittorrent"], "outboundTag": "blocked" }
    ]
  }
}
EOF

    mkdir -p /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log
    chmod 644 /var/log/xray/access.log /var/log/xray/error.log

    echo -e "${GREEN}配置文件生成成功。${NC}"
}

# 设置 systemd 服务
setup_systemd_service() {
    echo -e "${SKYBLUE}---> 5. 正在设置 systemd 服务...${NC}"
    cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=${XRAY_PATH}/xray run -config ${XRAY_CONFIG_PATH}/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray > /dev/null 2>&1
    echo -e "${GREEN}服务设置并启用开机自启完成。${NC}"
}

# 配置防火墙 (安全方式)
setup_firewall() {
    echo -e "${SKYBLUE}---> 6. 正在配置防火墙...${NC}"
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ssh > /dev/null 2>&1
        ufw allow ${VLESS_PORT}/tcp > /dev/null 2>&1
        ufw --force enable > /dev/null 2>&1
        echo -e "${GREEN}UFW 防火墙已配置并启用。端口 ${VLESS_PORT} 已开放。${NC}"
    else
        echo -e "${YELLOW}未检测到 UFW，跳过防火墙自动配置。${NC}"
        echo -e "${YELLOW}请手动确保服务器防火墙 (或云服务商安全组) 已开放 TCP 端口: ${VLESS_PORT}${NC}"
    fi
}

# 启动服务并显示节点信息
start_and_display_info() {
    echo -e "${SKYBLUE}---> 7. 正在启动 Xray 服务并生成节点信息...${NC}"
    
    systemctl restart xray
    sleep 2

    if ! systemctl is-active --quiet xray; then
        echo -e "${RED}错误: Xray 服务启动失败。${NC}"
        echo -e "${YELLOW}请运行 'systemctl status xray' 或 'journalctl -u xray' 查看详细日志。${NC}"
        exit 1
    fi

    PUBLIC_IP=$(curl -s --max-time 10 ipv4.icanhazip.com || curl -s --max-time 10 ip.sb || curl -s --max-time 10 ifconfig.me)
    if [ -z "$PUBLIC_IP" ]; then
        echo -e "${RED}错误: 无法获取公网 IP 地址。请手动配置。${NC}"
        PUBLIC_IP="YOUR_SERVER_IP"
    fi

    VLESS_URL="vless://${VLESS_UUID}@${PUBLIC_IP}:${VLESS_PORT}?encryption=none&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${VLESS_PUBLIC_KEY}&sid=${VLESS_SHORT_ID}&type=tcp&flow=xtls-rprx-vision#VLESS-Reality-${PUBLIC_IP}"

    # 清空并写入信息文件
    > "${XRAY_INFO_FILE}"
    {
        echo "=========== VLESS-Reality 节点信息 ==========="
        echo "地址 (Address): ${PUBLIC_IP}"
        echo "端口 (Port): ${VLESS_PORT}"
        echo "用户ID (UUID): ${VLESS_UUID}"
        echo "流控 (Flow): xtls-rprx-vision"
        echo "安全 (Security): reality"
        echo "SNI: ${REALITY_SNI}"
        echo "公钥 (PublicKey): ${VLESS_PUBLIC_KEY}"
        echo "短ID (ShortId): ${VLESS_SHORT_ID}"
        echo "============================================="
        echo "VLESS 链接 (URL):"
        echo "${VLESS_URL}"
        echo "============================================="
        echo "二维码 (QR Code):"
    } >> "${XRAY_INFO_FILE}"

    if command -v qrencode >/dev/null 2>&1; then
        qrencode -o - -t UTF8 "${VLESS_URL}" >> "${XRAY_INFO_FILE}"
    else
        echo "未安装 qrencode，无法生成二维码。" >> "${XRAY_INFO_FILE}"
    fi

    clear
    cat "${XRAY_INFO_FILE}"
    echo -e "\n${GREEN}安装成功！节点信息已保存在: ${YELLOW}${XRAY_INFO_FILE}${NC}"
    echo -e "${GREEN}您可以使用 'cat ${XRAY_INFO_FILE}' 命令随时查看。${NC}"
    echo -e "\n${SKYBLUE}常用管理命令:${NC}"
    echo -e "启动: ${YELLOW}systemctl start xray${NC}"
    echo -e "停止: ${YELLOW}systemctl stop xray${NC}"
    echo -e "重启: ${YELLOW}systemctl restart xray${NC}"
    echo -e "状态: ${YELLOW}systemctl status xray${NC}"
    echo -e "日志: ${YELLOW}journalctl -u xray -f --no-pager${NC}"
}

# --- 主逻辑 ---
main() {
    clear
    echo -e "${GREEN}欢迎使用 VLESS-Reality 一键安装脚本 (全自动修复版)${NC}"
    echo "----------------------------------------"
    
    check_root
    update_system
    install_prereqs
    get_user_port
    install_xray
    generate_vless_reality_config
    setup_systemd_service
    setup_firewall
    start_and_display_info
    
    echo "----------------------------------------"
    echo -e "${GREEN}部署流程全部完成。${NC}"
}

# 运行主函数
main
