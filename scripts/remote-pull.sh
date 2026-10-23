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
git fetch --quiet origin "$BRANCH"
git reset --hard --quiet "origin/$BRANCH"
echo "  版本: $(git log -1 --format='%h %s')"
