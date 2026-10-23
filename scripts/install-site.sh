#!/usr/bin/env bash
# 在服务器上执行一次：把 /etc/caddy/Caddyfile 指向本仓库的配置，校验并重载。
# 用法：sudo bash scripts/install-site.sh [域名]
# 之后每次改配置只需要 deploy.sh（它会自动重载）。
set -euo pipefail

SITE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="${1:-www.hao-rizon.com}"

if [ "$(id -u)" -ne 0 ]; then
	echo "请用 root 运行：sudo bash $0" >&2
	exit 1
fi
if [ ! -f "$SITE_DIR/deploy/Caddyfile" ]; then
	echo "找不到 $SITE_DIR/deploy/Caddyfile —— 请在仓库根目录里运行本脚本" >&2
	exit 1
fi
if ! command -v caddy >/dev/null 2>&1; then
	echo "caddy 未安装：先跑 sudo bash scripts/bootstrap-server.sh" >&2
	exit 1
fi

# Caddy 以 caddy 用户读配置和站点文件，路径上每一层都要能穿过去
chmod o+x "$(dirname "$SITE_DIR")" 2>/dev/null || true
chmod -R o+rX "$SITE_DIR/public" "$SITE_DIR/deploy"

echo "▶ 校验配置"
caddy validate --config "$SITE_DIR/deploy/Caddyfile" --adapter caddyfile

echo "▶ 让 /etc/caddy/Caddyfile 指向仓库里的配置（单一来源，不在服务器上分叉）"
ln -sfn "$SITE_DIR/deploy/Caddyfile" /etc/caddy/Caddyfile

echo "▶ 重载 Caddy"
systemctl reload caddy 2>/dev/null || systemctl restart caddy
sleep 2

echo "▶ 等待证书签发 / 站点响应（最多 45 秒）"
for _ in $(seq 1 15); do
	code=$(curl -sS -o /dev/null -w '%{http_code}' -m 8 "https://$DOMAIN/" 2>/dev/null || true)
	if [ "$code" = "200" ]; then
		echo "✓ https://$DOMAIN/ 已返回 200"
		exit 0
	fi
	sleep 3
done

echo "⚠ 45 秒内没拿到 200，排查顺序："
echo "   1. dig +short $DOMAIN          # 域名是否指向本机"
echo "   2. sudo systemctl status caddy"
echo "   3. sudo journalctl -u caddy -n 50 --no-pager"
echo "   4. 腾讯云安全组是否放行 80/443（和本机 ufw 是两道）"
exit 1
