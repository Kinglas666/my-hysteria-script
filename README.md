
Tired of `curl | bash`-ing random scripts from the internet and praying you don't wake up to a crypto miner on your server? Me too.
This isn't just another "one-click" script. This is **YOUR** one-click script, hosted on **YOUR** GitHub, with every line of code transparent and auditable. It's built on a simple, paranoid principle: **Trust No One, especially when it comes to root access.**
This script installs Hysteria 2 by fetching the binary directly from the official GitHub releases, sets it up with a secure configuration, and manages it with `systemd`. No magic, no backdoors, just pure, clean automation that you control.

厌倦了从网上随便找个链接，然后闭着眼睛 `curl | bash`，并祈祷第二天服务器不会变成别人的矿机？我也是。
所以，这不只是又一个“一键脚本”。这是**你自己的**一键脚本，托管在**你自己的** GitHub 仓库里，每一行代码都清晰透明、可供审计。它的核心原则只有一个，而且带点偏执：**别相信任何人，尤其是在交出 root 权限的时候。**
本脚本通过从 Hysteria 官方 GitHub Releases 页面直接拉取程序，为你安装 Hysteria 2，并使用 `systemd` 进行标准化服务管理。没有黑魔法，没有后门，只有你亲手掌控的、纯净的自动化。

## ✨ Features / 核心特性

*   **🛡️ Maximum Security / 极致安全**
    *   🇬🇧 Downloads directly from the **official Hysteria GitHub Releases**. No third-party binaries, no risk of tampering.
    *   🇨🇳 直接从 **Hysteria 官方 GitHub Releases** 下载程序，拒绝任何第三方编译，从源头杜绝篡改风险。

*   **👀 Fully Transparent / 完全透明**
    *   🇬🇧 No obfuscated code. You are encouraged to read the script. After all, it's in your own repository!
    *   🇨🇳 没有任何混淆代码。我们鼓励你阅读脚本的每一行——毕竟，它就躺在你的仓库里！

*   **🤖 Smart & Interactive / 智能交互**
    *   🇬🇧 Automatically detects your server's architecture (amd64/arm64) and prompts you for necessary information like your domain and password.
    *   🇨🇳 自动检测服务器的 CPU 架构 (amd64/arm64)，并交互式地询问你的域名和密码等必要信息。

*   **⚙️ Standardized Management / 标准化管理**
    *   🇬🇧 Creates a `systemd` service for easy management (start, stop, restart, auto-start on boot).
    *   🇨🇳 自动创建 `systemd` 服务，方便你对 Hysteria 进行启动、停止、重启和设置开机自启。

*   **🔑 Automatic TLS / 自动证书**
    *   🇬🇧 Utilizes ACME to automatically apply for and renew Let's Encrypt certificates, keeping your connection secure.
    *   🇨🇳 集成 ACME 功能，为你自动申请并续签 Let's Encrypt 免费证书，确保连接始终加密。

---

## 🚀 Usage / 如何使用

### Prerequisites / 前提条件

1.  A VPS running Debian or Ubuntu. / 🇨🇳 一台运行 Debian 或 Ubuntu 的服务器。
2.  A domain name pointed to your server's IP address. / 🇨🇳 一个已经解析到你服务器 IP 的域名。
3.  Root access to your VPS. / 🇨🇳 服务器的 root 权限。

### Installation / 一键安装

Connect to your VPS and run the following command. 
<br>
连接到你的 VPS，并执行以下命令。

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Kinglas666/my-hysteria-script/main/install.sh)
```

亚马逊VPS  hysteria 2 协议
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Kinglas666/my-hysteria-script/main/install-aws.sh)
```

The script will then guide you to enter your domain name and your desired Hysteria 2 access password.

脚本将引导你输入你的域名和你希望设定的 Hysteria 2 访问密码。

---

## 🛠️ Post-Installation / 安装后操作 (VERY IMPORTANT / 非常重要)

The script will **NOT** modify your firewall for security reasons. You must open the necessary ports manually.
<br>
出于安全考虑，脚本**不会**自动修改你的防火墙。你必须手动开放所需端口。

If you are using `ufw`:
<br>
如果你在使用 `ufw` 防火墙：

```bash
# 开放端口
ufw allow 443/udp
ufw allow 80/tcp
ufw allow ssh

# 启用防火墙
ufw enable
---

## 🕹️ Management Commands / 管理命令
```
| Command (命令)                                    | Description (描述)                            |
| ------------------------------------------------- | --------------------------------------------- |
| `sudo systemctl start hysteria-server.service`    | 🇬🇧 Start the service / 🇨🇳 启动服务          |
| `sudo systemctl stop hysteria-server.service`     | 🇬🇧 Stop the service / 🇨🇳 停止服务           |
| `sudo systemctl restart hysteria-server.service`  | 🇬🇧 Restart the service / 🇨🇳 重启服务        |
| `sudo systemctl status hysteria-server.service`   | 🇬🇧 Check the status / 🇨🇳 查看状态           |
| `sudo systemctl enable hysteria-server.service`   | 🇬🇧 Enable auto-start on boot / 🇨🇳 设置开机自启 |
| `sudo systemctl disable hysteria-server.service`  | 🇬🇧 Disable auto-start on boot / 🇨🇳 取消开机自启 |
```
The configuration file is located at `/etc/hysteria/config.yaml`.
<br>
配置文件位于 `/etc/hysteria/config.yaml`。

---

## 📜 Disclaimer / 免责声明

This script is provided "as-is" without any warranty. Use at your own risk. I am not responsible for any damage or loss.
<br>
本脚本按“原样”提供，不作任何保证。使用风险自负，作者不对任何损坏或损失负责。

## 📄 License / 许可证

This project is licensed under the MIT License.
<br>
本项目基于 MIT 许可证开源。

<!-- END OF README -->
