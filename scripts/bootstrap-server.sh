#!/usr/bin/env bash
# 在全新的 Ubuntu/Debian 服务器上执行一次（需要 root）。
# 装 Caddy（官方源，自动 HTTPS）+ Git + 防火墙，之后部署只需要 git pull。
# 用法：sudo bash scripts/bootstrap-server.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "请用 root 运行：sudo bash $0" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "▶ 安装基础工具"
apt-get update -qq
apt-get install -y --no-install-recommends \
	ca-certificates curl gnupg git ufw \
	debian-keyring debian-archive-keyring apt-transport-https

echo "▶ 添加 Caddy 官方软件源"
if [ ! -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg ]; then
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' |
		gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
		>/etc/apt/sources.list.d/caddy-stable.list
fi

apt-get update -qq
apt-get install -y --no-install-recommends caddy

echo "▶ 放行 22 / 80 / 443（本机防火墙）"
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null

systemctl enable --now caddy

echo "▶ 端口自检"
if ss -ltnp 2>/dev/null | grep -qE ':(80|443)\s'; then
	ss -ltnp 2>/dev/null | grep -E ':(80|443)\s' || true
	echo "  ↑ 如果占用者不是 caddy，先停掉它：Caddy 需要独占 80/443"
fi
if command -v nginx >/dev/null 2>&1; then
	echo "  ⚠ 系统里装了 nginx：如果它在跑，会和 Caddy 抢 80/443 —— sudo systemctl disable --now nginx"
fi

echo "✓ 完成。接下来在服务器上："
echo "   cd /srv/haorizon && sudo bash scripts/install-site.sh"
