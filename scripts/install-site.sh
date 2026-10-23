#!/usr/bin/env bash
# 在服务器上执行一次：安装 nginx 站点配置 + 申请证书。
# 用法：sudo bash scripts/install-site.sh <域名> [证书邮箱]
# 例：  sudo bash scripts/install-site.sh hao-rizon.com me@example.com
set -euo pipefail

DOMAIN="${1:?用法: sudo bash scripts/install-site.sh <域名> [证书邮箱]}"
EMAIL="${2:-}"
SITE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAME=haorizon
CONF="/etc/nginx/sites-available/$NAME.conf"

if [ "$(id -u)" -ne 0 ]; then
	echo "请用 root 运行：sudo bash $0 $*" >&2
	exit 1
fi
if [ ! -d "$SITE_DIR/public" ]; then
	echo "找不到 $SITE_DIR/public —— 请在仓库根目录里运行本脚本" >&2
	exit 1
fi

# 端口被别的进程占着时，先讲清楚，免得 nginx -t 通过但网站打不开
if ss -ltnp 2>/dev/null | grep -qE ':80\s' && ! ss -ltnp 2>/dev/null | grep -qE ':80\s.*nginx'; then
	echo "⚠ 80 端口已被非 nginx 进程占用：" >&2
	ss -ltnp 2>/dev/null | grep -E ':80\s' >&2 || true
	echo "  改用 Caddy 方案：见 deploy/Caddyfile.site" >&2
	exit 1
fi

echo "▶ 写入 $CONF（域名 $DOMAIN，根目录 $SITE_DIR/public）"
sed -e "s|__DOMAIN__|$DOMAIN|g" \
	-e "s|__ROOT__|$SITE_DIR/public|g" \
	-e "s|__NAME__|$NAME|g" \
	"$SITE_DIR/deploy/nginx-site.conf" >"$CONF"

ln -sfn "$CONF" "/etc/nginx/sites-enabled/$NAME.conf"
[ -e /etc/nginx/sites-enabled/default ] && rm -f /etc/nginx/sites-enabled/default

# 静态文件要让 nginx 的 worker 读得到：目录可执行、文件可读
chmod o+x "$(dirname "$SITE_DIR")" 2>/dev/null || true
chmod -R o+rX "$SITE_DIR/public"

echo "▶ 校验配置"
nginx -t
systemctl reload nginx
echo "✓ 站点已启用（HTTP）"

if [ -n "$EMAIL" ]; then
	echo "▶ 申请 Let's Encrypt 证书并自动配置 HTTPS"
	certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --redirect --non-interactive
	certbot renew --dry-run | tail -3
	echo "✓ HTTPS 就绪。验证：curl -I https://$DOMAIN"
else
	echo "ℹ 未提供邮箱，跳过证书。稍后执行："
	echo "   sudo certbot --nginx -d $DOMAIN -m <你的邮箱> --agree-tos --redirect"
fi
