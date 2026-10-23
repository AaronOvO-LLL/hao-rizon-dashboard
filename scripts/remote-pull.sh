#!/usr/bin/env bash
# 由 scripts/deploy.sh 通过 ssh 送到服务器执行，不要手动在本地跑。
# 输入（环境变量）：SITE_PATH / BRANCH / REPO_URL
set -euo pipefail

: "${SITE_PATH:?}" "${BRANCH:?}" "${REPO_URL:?}"

if [ ! -d "$SITE_PATH/.git" ]; then
	echo "  首次部署：克隆 $REPO_URL"
	parent="$(dirname "$SITE_PATH")"
	if [ ! -w "$parent" ]; then
		sudo mkdir -p "$parent"
		sudo chown "$(id -un):$(id -gn)" "$parent"
	fi
	git clone --quiet --branch "$BRANCH" "$REPO_URL" "$SITE_PATH"
fi

cd "$SITE_PATH"
before=$(git rev-parse HEAD 2>/dev/null || echo none)
git fetch --quiet origin "$BRANCH"
git reset --hard --quiet "origin/$BRANCH"
after=$(git rev-parse HEAD)
echo "  版本: $(git log -1 --format='%h %s')"

# 站点文件是 Caddy 直接从工作目录读的，文件更新即时生效；只有配置变了才需要重载
if [ "$before" != "$after" ] && git diff --name-only "$before" "$after" 2>/dev/null | grep -qx 'deploy/Caddyfile'; then
	echo "  Caddyfile 有变更 → 校验后重载"
	if sudo -n true 2>/dev/null; then
		if sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
			sudo systemctl reload caddy
			echo "  ✓ 已重载 caddy"
		else
			echo "  ✗ 新配置校验失败，未重载（站点保持旧配置运行）" >&2
			exit 1
		fi
	else
		echo "  ⚠ 需要 sudo 密码，重载请手动执行：sudo systemctl reload caddy"
	fi
fi

