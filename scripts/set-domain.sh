#!/usr/bin/env bash
# 把占位域名 hao-rizon.example 换成真实域名（只改文件，不提交）。
# 用法：./scripts/set-domain.sh hao-rizon.com
set -euo pipefail
NEW="${1:?用法: ./scripts/set-domain.sh <域名，不带 https://>}"
NEW="${NEW#http://}"
NEW="${NEW#https://}"
NEW="${NEW%/}"
OLD='hao-rizon\.example'
cd "$(dirname "$0")/.."

found=0
while IFS= read -r f; do
	found=1
	sed -i "s|$OLD|$NEW|g" "$f"
	echo "  ✓ $f"
done < <(grep -rl 'hao-rizon\.example' public deploy deploy.env.example 2>/dev/null || true)

if [ "$found" -eq 0 ]; then
	echo "没有发现占位域名，可能已经改过了。"
else
	echo "已替换为 $NEW —— 记得 git commit 后再发布。"
fi
