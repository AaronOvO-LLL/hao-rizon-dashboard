#!/usr/bin/env bash
# 本地一键发布：推送 GitHub → 服务器拉取 → 线上探活。
# 参数全部来自 deploy.env（复制 deploy.env.example 得到，不入库）。
# 用法：./scripts/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f deploy.env ]; then
	set -a
	# shellcheck disable=SC1091
	. ./deploy.env
	set +a
fi

: "${SITE_HOST:?缺少 SITE_HOST：cp deploy.env.example deploy.env 后填写}"
SITE_USER=${SITE_USER:-ubuntu}
SITE_PATH=${SITE_PATH:-/srv/haorizon}
BRANCH=${BRANCH:-main}
SSH_TARGET="$SITE_USER@$SITE_HOST"

if [ -n "$(git status --porcelain)" ]; then
	echo "✗ 有未提交的改动，先 commit（发布只发布 git 里的内容）"
	git status --short
	exit 1
fi

if grep -rq 'hao-rizon\.example' public/ 2>/dev/null; then
	echo "⚠ public/ 里还有占位域名 hao-rizon.example"
	echo "  确定域名后先跑：./scripts/set-domain.sh <你的域名>"
	echo
fi

# 服务器需要一个能匿名访问的仓库地址；本机 remote 是 SSH 时自动换算成 HTTPS
REPO_URL=${SITE_REPO:-}
if [ -z "$REPO_URL" ]; then
	raw=$(git remote get-url origin 2>/dev/null || true)
	case "$raw" in
		https://*) REPO_URL="$raw" ;;
		*github.com*)
			slug=$(printf '%s' "$raw" | sed -n 's|.*github\.com\(:[0-9]\+\)\?[:/]\(.*\)\.git$|\2|p')
			[ -n "$slug" ] && REPO_URL="https://github.com/$slug.git"
			;;
	esac
fi
if [ -z "$REPO_URL" ]; then
	echo "✗ 无法确定仓库地址：请先在 deploy.env 里设置 SITE_REPO=https://github.com/<你>/<仓库>.git"
	exit 1
fi

echo "▶ 1/3 推送到 GitHub"
git push origin "$BRANCH"

echo "▶ 2/3 服务器拉取（$SSH_TARGET:$SITE_PATH）"
ssh -o BatchMode=yes -o ConnectTimeout=20 "$SSH_TARGET" \
	"SITE_PATH='$SITE_PATH' BRANCH='$BRANCH' REPO_URL='$REPO_URL' bash -s" <scripts/remote-pull.sh

echo "▶ 3/3 线上探活"
if [ -n "${SITE_DOMAIN:-}" ] && [ "${SITE_DOMAIN}" != "hao-rizon.example" ]; then
	code=$(curl -sS -m 20 -o /dev/null -w '%{http_code}' "https://$SITE_DOMAIN/" || true)
	echo "  https://$SITE_DOMAIN/ → ${code:-无响应}"
	if [ "${code:-}" != "200" ]; then
		code80=$(curl -sS -m 20 -o /dev/null -w '%{http_code}' "http://$SITE_DOMAIN/" || true)
		echo "  http://$SITE_DOMAIN/  → ${code80:-无响应}"
		echo "  200 之外通常是：DNS 未生效 / 证书未申请 / nginx 站点未启用。见 README 排查表。"
	fi
else
	echo "  未配置域名，跳过。可先手动看：curl -I http://$SITE_HOST/"
fi
echo "✓ 发布流程结束"
