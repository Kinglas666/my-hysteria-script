# VLESS-Reality 一键安装脚本

这是一个精简、安全、专注于部署 **VLESS-Reality** 协议的 Shell 脚本。它旨在为用户提供一个纯净、无后门的自动化部署方案，仅包含搭建一个高性能 VLESS 节点所需的核心功能。

## ✨ 功能特性

- **协议**: 仅支持 VLESS + TCP + Reality (Vision Flow)，无需域名，抗审查能力强。
- **核心**: 使用官方最新版本的 [Xray-core](https://github.com/XTLS/Xray-core)。
- **自动化**: 自动更新系统、安装依赖、配置并启动服务。
- **自定义端口**: 脚本会提示您输入一个自定义端口，增强隐蔽性。
- **防火墙**: 自动配置并启用 `UFW` 防火墙，仅开放必要端口。
- **开机自启**: 自动创建并启用 `systemd` 服务，确保服务器重启后服务能自动运行。
- **信息展示**: 部署完成后，清晰地显示 VLESS 连接链接和二维码，并保存到文件中供随时查看。

## 💻 系统要求

- **操作系统**: Debian 10+ / Ubuntu 20.04+
- **架构**: x86_64 / amd64 / aarch64
- **权限**: 需要 `root` 权限来运行此脚本。

## 🚀 部署命令

通过 SSH 连接到您的 VPS，然后执行以下单行命令即可开始部署。脚本会自动获取 `root` 权限。

```bash
wget -O install-vless.sh [您的脚本文件在GitHub上的RAW链接] && sudo bash install-vless.sh
