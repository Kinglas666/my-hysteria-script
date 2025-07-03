#!/bin/bash

# VLESS-Reality 一键安装脚本
# 作者: Your Name (根据 mack-a 脚本精简和重构)
# Github: your-github-repo-url

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

# Reality 目标服务器 (一个大型、可靠、支持TLS 1.3的网站)
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
    echo -e "${SKYBLUE}---> 1. 正在更新系统软件包列表和已安装的包...${NC}"
    apt update > /dev/null 2>&1
    apt upgrade -y > /dev/null 2>&1
    echo -e "${GREEN}系统更新完成。${NC}"
}

# 安装依赖
install_prereqs() {
    echo -e "${SKYBLUE}---> 2. 正在安装必要的依赖软件...${NC}"
    apt install -y wget curl unzip ufw qrencode jq > /dev/null 2>&1
    echo -e "${GREEN}依赖软件安装完成。${NC}"
}

# 获取用户输入的端口
get_user_port() {
    while true; do
        read -p "$(echo -e ${YELLOW}"请输入 VLESS 端口号 (建议范围 35000-36000): "${NC})" VLESS_PORT
        # 检查输入是否为数字
        if [[ "$VLESS_PORT" =~ ^[0-9]+$ ]] && [ "$VLESS_PORT" -gt 0 ] && [ "$VLESS_PORT" -le 65535 ]; then
            echo -e "${GREEN}VLESS 将使用端口: ${VLESS_PORT}${NC}"
            break
        else
            echo -e "${RED}输入无效。请输入一个 1-65535 之间的数字。${NC}"
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
        *)
            echo -e "${RED}错误: 不支持的CPU架构: $ARCH${NC}"
            exit 1
            ;;
    esac

    # 获取最新版本号
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | jq -r '.tag_name')
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}错误: 无法获取 Xray-core 最新版本号。请检查网络连接或 Github API 状态。${NC}"
        exit 1
    fi
    echo -e "${GREEN}检测到 Xray-core 最新版本: ${LATEST_VERSION}${NC}"

    # 下载并解压
    wget -qO "${XRAY_PATH}/xray.zip" "https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/${CPU_VENDOR}.zip"
    unzip -o "${XRAY_PATH}/xray.zip" -d "${XRAY_PATH}" > /dev/null 2>&1
    rm "${XRAY_PATH}/xray.zip"
    chmod +x "${XRAY_PATH}/xray"

    if [ ! -f "${XRAY_PATH}/xray" ]; then
        echo -e "${RED}错误: Xray-core 安装失败。${NC}"
        exit 1
    fi
    echo -e "${GREEN}Xray-core 安装成功。${NC}"
}

# 生成 VLESS-Reality 配置文件
generate_vless_reality_config() {
    echo -e "${SKYBLUE}---> 4. 正在生成 VLESS-Reality 配置文件...${NC}"
    
    # 生成 UUID 和密钥对
    UUID=$(${XRAY_PATH}/xray uuid)
    KEYS=$(${XRAY_PATH}/xray x25519)
    PRIVATE_KEY=$(echo "$KEYS" | awk '/Private key:/ {print $3}')
    PUBLIC_KEY=$(echo "$KEYS" | awk '/Public key:/ {print $3}')
    
    # 将配置信息保存到变量中，便于后续显示
    VLESS_UUID=${UUID}
    VLESS_PRIVATE_KEY=${PRIVATE_KEY}
    VLESS_PUBLIC_KEY=${PUBLIC_KEY}

    # 创建配置文件
    cat > "${XRAY_CONFIG_PATH}/01_vless_reality.json" <<EOF
{
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
            ""
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ]
}
EOF
    
    # 创建基础日志和DNS配置
    cat > "${XRAY_CONFIG_PATH}/00_log.json" <<'EOF'
{
  "log": {
    "loglevel": "warning"
  }
}
EOF
    cat > "${XRAY_CONFIG_PATH}/10_dns.json" <<'EOF'
{
  "dns": {
    "servers": [
      "https-dns.hkg.ap.nextdns.io",
      "1.1.1.1",
      "8.8.8.8",
      "localhost"
    ]
  }
}
EOF

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
ExecStart=${XRAY_PATH}/xray run -confdir ${XRAY_CONFIG_PATH}
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
    echo -e "${SKYBLUE}---> 6. 正在配置 UFW 防火墙...${NC}"
    
    # 禁用以避免冲突
    systemctl stop ufw > /dev/null 2>&1

    # 开放必要端口
    ufw allow ssh > /dev/null 2>&1
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/udp > /dev/null 2>&1 # for QUIC
    ufw allow ${VLESS_PORT}/tcp > /dev/null 2>&1
    ufw allow ${VLESS_PORT}/udp > /dev/null 2>&1

    # 启用防火墙
    ufw --force enable
    
    echo -e "${GREEN}防火墙配置完成。已开放端口: SSH, 80/tcp, 443/udp, ${VLESS_PORT}/tcp+udp${NC}"
}


# 启动服务并显示节点信息
start_and_display_info() {
    echo -e "${SKYBLUE}---> 7. 正在启动 Xray 服务并生成节点信息...${NC}"
    systemctl start xray
    
    # 稍作等待，确保服务已启动
    sleep 2

    # 检查服务状态
    if ! systemctl is-active --quiet xray; then
        echo -e "${RED}错误: Xray 服务启动失败。${NC}"
        echo -e "${YELLOW}请运行 'sudo systemctl status xray' 或 'journalctl -u xray -e' 查看日志。${NC}"
        exit 1
    fi

    # 获取公网 IP
    PUBLIC_IP=$(curl -s ip.sb)
    if [ -z "$PUBLIC_IP" ]; then
        echo -e "${RED}错误: 无法获取公网 IP 地址。${NC}"
        exit 1
    fi

    # 生成 VLESS 链接
    VLESS_URL="vless://${VLESS_UUID}@${PUBLIC_IP}:${VLESS_PORT}?encryption=none&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${VLESS_PUBLIC_KEY}&sid=&type=tcp&flow=xtls-rprx-vision#VLESS-Reality"

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
}

# --- 主逻辑 ---
main() {
    clear
    echo -e "${GREEN}欢迎使用 VLESS-Reality 一键安装脚本！${NC}"
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

main
