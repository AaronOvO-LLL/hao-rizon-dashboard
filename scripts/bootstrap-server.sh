#!/usr/bin/env bash
# 在全新的 Ubuntu/Debian 服务器上执行一次（需要 root）。
# 目的：装好证书、Git、防火墙三件套，让后续部署只需要 git pull。
# 用法：sudo bash scripts/bootstrap-server.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "请用 root 运行：sudo bash $0" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "▶ 更新软件包索引"
apt-get update -qq

echo "▶ 安装 nginx / git / certbot / ufw"
apt-get install -y --no-install-recommends \
	nginx git curl ca-certificates ufw certbot python3-certbot-nginx

echo "▶ 放行 22 / 80 / 443（本机防火墙）"
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null

systemctl enable --now nginx

# 端口冲突自检：如果有别的服务（例如 Caddy 容器）已经在占 80/443，这里会暴露出来
if ss -ltnp 2>/dev/null | grep -qE ':(80|443)\s' ; then
	echo "ℹ 80/443 已有进程在监听："
	ss -ltnp 2>/dev/null | grep -E ':(80|443)\s' || true
	echo "  如果那是 Caddy（obsidian-sync-hub），不要用 nginx 方案，改用 deploy/Caddyfile.site。"
fi

echo "✓ 完成。接下来在服务器上："
echo "   1) git clone <仓库地址> /srv/haorizon"
echo "   2) cd /srv/haorizon && sudo bash scripts/install-site.sh <域名> <证书邮箱>"
