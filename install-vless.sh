#!/bin/bash

# VLESS-Reality 一键安装脚本 (修复版)
# 修复了 Reality 配置和连接问题

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

# Reality 目标服务器 (更换为更稳定的目标)
REALITY_SNI="www.yahoo.com"
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
    echo -e "${SKYBLUE}---> 1. 正在更新系统软件包列表和已安装的包...${NC}"
    apt update > /dev/null 2>&1
    apt upgrade -y > /dev/null 2>&1
    echo -e "${GREEN}系统更新完成。${NC}"
}

# 安装依赖
install_prereqs() {
    echo -e "${SKYBLUE}---> 2. 正在安装必要的依赖软件...${NC}"
    apt install -y wget curl unzip ufw qrencode jq openssl > /dev/null 2>&1
    echo -e "${GREEN}依赖软件安装完成。${NC}"
}

# 获取用户输入的端口
get_user_port() {
    while true; do
        read -p "$(echo -e ${YELLOW}"请输入 VLESS 端口号 (建议范围 10000-65000): "${NC})" VLESS_PORT
        # 检查输入是否为数字
        if [[ "$VLESS_PORT" =~ ^[0-9]+$ ]] && [ "$VLESS_PORT" -gt 1024 ] && [ "$VLESS_PORT" -le 65535 ]; then
            # 检查端口是否被占用
            if ! netstat -tuln | grep -q ":$VLESS_PORT "; then
                echo -e "${GREEN}VLESS 将使用端口: ${VLESS_PORT}${NC}"
                break
            else
                echo -e "${RED}端口 ${VLESS_PORT} 已被占用，请选择其他端口。${NC}"
            fi
        else
            echo -e "${RED}输入无效。请输入一个 1024-65535 之间的数字。${NC}"
        fi
    done
}

# 安装 Xray-core
install_xray() {
    echo -e "${SKYBLUE}---> 3. 正在安装 Xray-core...${NC}"
    mkdir -p "${XRAY_PATH}" "${XRAY_CONFIG_PATH}"
    
    # 确定CPU架构
    ARCH=$(uname -m)
    case "$ARCH" in
        'x86_64' | 'amd64')
            CPU_VENDOR="Xray-linux-64"
            ;;
        'aarch64' | 'arm64')
            CPU_VENDOR="Xray-linux-arm64-v8a"
            ;;
        'armv7l')
            CPU_VENDOR="Xray-linux-arm32-v7a"
            ;;
        *)
            echo -e "${RED}错误: 不支持的CPU架构: $ARCH${NC}"
            exit 1
            ;;
    esac

    # 获取最新版本号
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | jq -r '.tag_name')
    if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" == "null" ]; then
        echo -e "${YELLOW}警告: 无法获取最新版本，使用默认版本 v1.8.4${NC}"
        LATEST_VERSION="v1.8.4"
    fi
    echo -e "${GREEN}使用 Xray-core 版本: ${LATEST_VERSION}${NC}"

    # 下载并解压
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/${CPU_VENDOR}.zip"
    echo -e "${SKYBLUE}正在下载: ${DOWNLOAD_URL}${NC}"
    
    if ! wget -qO "${XRAY_PATH}/xray.zip" "${DOWNLOAD_URL}"; then
        echo -e "${RED}错误: 下载 Xray-core 失败。${NC}"
        exit 1
    fi
    
    unzip -o "${XRAY_PATH}/xray.zip" -d "${XRAY_PATH}" > /dev/null 2>&1
    rm "${XRAY_PATH}/xray.zip"
    chmod +x "${XRAY_PATH}/xray"

    if [ ! -f "${XRAY_PATH}/xray" ]; then
        echo -e "${RED}错误: Xray-core 安装失败。${NC}"
        exit 1
    fi
    echo -e "${GREEN}Xray-core 安装成功。${NC}"
}

# 生成随机的 shortId
generate_short_id() {
    openssl rand -hex 8 | cut -c1-8
}

# 生成 VLESS-Reality 配置文件
generate_vless_reality_config() {
    echo -e "${SKYBLUE}---> 4. 正在生成 VLESS-Reality 配置文件...${NC}"
    
    # 生成 UUID 和密钥对
    UUID=$(${XRAY_PATH}/xray uuid)
    KEYS=$(${XRAY_PATH}/xray x25519)
    PRIVATE_KEY=$(echo "$KEYS" | awk '/Private key:/ {print $3}')
    PUBLIC_KEY=$(echo "$KEYS" | awk '/Public key:/ {print $3}')
    
    # 生成随机的 shortId
    SHORT_ID=$(generate_short_id)
    
    # 将配置信息保存到变量中，便于后续显示
    VLESS_UUID=${UUID}
    VLESS_PRIVATE_KEY=${PRIVATE_KEY}
    VLESS_PUBLIC_KEY=${PUBLIC_KEY}
    VLESS_SHORT_ID=${SHORT_ID}

    # 创建配置文件
    cat > "${XRAY_CONFIG_PATH}/config.json" <<EOF
{
  "log": {
    "loglevel": "info",
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
          "maxTimeDiff": 60000,
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
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      },
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "blocked"
      }
    ]
  },
  "dns": {
    "servers": [
      "8.8.8.8",
      "1.1.1.1",
      "114.114.114.114"
    ]
  }
}
EOF

    # 创建日志目录
    mkdir -p /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log

    echo -e "${GREEN}配置文件生成成功。${NC}"
}

# 设置 systemd 服务和开机自启
setup_systemd_service() {
    echo -e "${SKYBLUE}---> 5. 正在设置 systemd 服务并启用开机自启...${NC}"
    cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
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
    echo -e "${GREEN}服务设置完成。${NC}"
}

# 配置防火墙
setup_firewall() {
    echo -e "${SKYBLUE}---> 6. 正在配置防火墙...${NC}"
    
    # 检查是否已安装 ufw
    if command -v ufw >/dev/null 2>&1; then
        # 重置 ufw 规则
        ufw --force reset > /dev/null 2>&1
        
        # 设置默认规则
        ufw default deny incoming > /dev/null 2>&1
        ufw default allow outgoing > /dev/null 2>&1
        
        # 允许 SSH
        ufw allow ssh > /dev/null 2>&1
        ufw allow 22/tcp > /dev/null 2>&1
        
        # 允许 VLESS 端口
        ufw allow ${VLESS_PORT}/tcp > /dev/null 2>&1
        
        # 启用防火墙
        ufw --force enable > /dev/null 2>&1
        echo -e "${GREEN}UFW 防火墙配置完成。${NC}"
    else
        echo -e "${YELLOW}未检测到 UFW，跳过防火墙配置。${NC}"
    fi
}

# 启动服务并显示节点信息
start_and_display_info() {
    echo -e "${SKYBLUE}---> 7. 正在启动 Xray 服务并生成节点信息...${NC}"
    
    # 启动服务
    systemctl start xray
    
    # 等待服务启动
    sleep 3

    # 检查服务状态
    if ! systemctl is-active --quiet xray; then
        echo -e "${RED}错误: Xray 服务启动失败。${NC}"
        echo -e "${YELLOW}正在查看服务状态...${NC}"
        systemctl status xray --no-pager
        echo -e "${YELLOW}正在查看日志...${NC}"
        journalctl -u xray -n 20 --no-pager
        exit 1
    fi

    # 获取公网 IP
    PUBLIC_IP=$(curl -s --max-time 10 ipv4.icanhazip.com)
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(curl -s --max-time 10 ip.sb)
    fi
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me)
    fi
    if [ -z "$PUBLIC_IP" ]; then
        echo -e "${RED}错误: 无法获取公网 IP 地址。${NC}"
        exit 1
    fi

    # 生成 VLESS 链接
    VLESS_URL="vless://${VLESS_UUID}@${PUBLIC_IP}:${VLESS_PORT}?encryption=none&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${VLESS_PUBLIC_KEY}&sid=${VLESS_SHORT_ID}&type=tcp&flow=xtls-rprx-vision#VLESS-Reality-${PUBLIC_IP}"

    # 清空并写入信息文件
    > "${XRAY_INFO_FILE}"
    echo "=========== VLESS-Reality 节点信息 ===========" >> "${XRAY_INFO_FILE}"
    echo "地址 (Address): ${PUBLIC_IP}" >> "${XRAY_INFO_FILE}"
    echo "端口 (Port): ${VLESS_PORT}" >> "${XRAY_INFO_FILE}"
    echo "用户ID (UUID): ${VLESS_UUID}" >> "${XRAY_INFO_FILE}"
    echo "流控 (Flow): xtls-rprx-vision" >> "${XRAY_INFO_FILE}"
    echo "加密 (Encryption): none" >> "${XRAY_INFO_FILE}"
    echo "传输 (Network): tcp" >> "${XRAY_INFO_FILE}"
    echo "安全 (Security): reality" >> "${XRAY_INFO_FILE}"
    echo "SNI: ${REALITY_SNI}" >> "${XRAY_INFO_FILE}"
    echo "公钥 (PublicKey): ${VLESS_PUBLIC_KEY}" >> "${XRAY_INFO_FILE}"
    echo "短ID (ShortId): ${VLESS_SHORT_ID}" >> "${XRAY_INFO_FILE}"
    echo "指纹 (Fingerprint): chrome" >> "${XRAY_INFO_FILE}"
    echo "=============================================" >> "${XRAY_INFO_FILE}"
    echo "VLESS 链接 (URL):" >> "${XRAY_INFO_FILE}"
    echo "${VLESS_URL}" >> "${XRAY_INFO_FILE}"
    echo "=============================================" >> "${XRAY_INFO_FILE}"
    echo "二维码 (QR Code):" >> "${XRAY_INFO_FILE}"
    qrencode -o - -t UTF8 "${VLESS_URL}" >> "${XRAY_INFO_FILE}"

    # 在屏幕上显示信息
    clear
    cat "${XRAY_INFO_FILE}"
    echo -e "\n${GREEN}安装成功！节点信息已保存在: ${YELLOW}${XRAY_INFO_FILE}${NC}"
    echo -e "${GREEN}您可以使用 'cat ${XRAY_INFO_FILE}' 命令随时查看。${NC}"
    echo -e "\n${SKYBLUE}管理命令:${NC}"
    echo -e "启动服务: ${YELLOW}systemctl start xray${NC}"
    echo -e "停止服务: ${YELLOW}systemctl stop xray${NC}"
    echo -e "重启服务: ${YELLOW}systemctl restart xray${NC}"
    echo -e "查看状态: ${YELLOW}systemctl status xray${NC}"
    echo -e "查看日志: ${YELLOW}journalctl -u xray -f${NC}"
}

# --- 主逻辑 ---
main() {
    clear
    echo -e "${GREEN}欢迎使用 VLESS-Reality 一键安装脚本！(修复版)${NC}"
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
    echo -e "${YELLOW}注意: 如果连接失败，请检查服务器防火墙设置和安全组配置。${NC}"
}

main
