# Hao-rizon — 个人主页

单页静态站：纯 HTML / CSS / JS，**零依赖、零构建**。改了文件就是改了网站，服务器只负责把它发出去。

当前版本：v0.1「赤色构成」原型（`public/index.html`）。
`archive/cubism/` 是上一版方案（碎面 / AARON.HUB），只作存档，不参与部署。

## 目录

```
public/             ← 服务器真正对外提供的文件（网站根目录）
  index.html          首页
  404.html            找不到页面
  robots.txt
  assets/favicon.svg
deploy/
  nginx-site.conf     nginx 站点配置模板（用 nginx 时）
  Caddyfile.site      已有 Caddy 时追加的站点块
scripts/
  deploy.sh           本机：push + 服务器拉取 + 探活
  bootstrap-server.sh 服务器首次：装 nginx/git/certbot/ufw
  install-site.sh     服务器首次：装站点配置 + 申请证书
  remote-pull.sh      deploy.sh 通过 ssh 送到服务器执行的拉取脚本
  set-domain.sh       把占位域名换成真实域名
deploy.env.example   本机部署参数模板（复制成 deploy.env）
```

## 本地预览

```bash
python -m http.server 8080 --directory public
# 浏览器打开 http://localhost:8080/
```

必须用 HTTP 服务打开，不要双击 `file://`——`/assets/...` 这类根路径在 `file://` 下会失效。

## 上线：一次性三步

### 0. 先核对（这四条任何一条不满足，站点都上不去）

| 检查项 | 说明 |
|---|---|
| 域名 A 记录 | `你的域名 → 服务器公网 IP`，`dig +short 你的域名` 能查到 IP |
| 安全组 | 腾讯云控制台的**安全组**放行 80/443（本机 ufw 是另一道，两道都要开） |
| ICP 备案 | 服务器在中国大陆（如广州/上海）时，域名必须先备案才能用 80/443 对外提供网站 |
| 80/443 归属 | 一台机器上只能有一个进程监听 80/443。已装 Caddy（例如同步中枢）就走 Caddy 路线，不要再装 nginx |

### 1. 仓库推到 GitHub

```bash
git remote add origin git@github.com:AaronOvO-LLL/<仓库名>.git
git push -u origin main
```

**建议公开仓库**：服务器要能 `git clone`，公开仓库走 HTTPS 不需要在服务器上配部署密钥。站点内容本来就是公开的。

### 2. 服务器准备（在服务器上执行）

```bash
ssh ubuntu@<公网IP>
sudo apt-get update && sudo apt-get install -y git      # 镜像一般已装
sudo git clone https://github.com/AaronOvO-LLL/<仓库名>.git /srv/haorizon
cd /srv/haorizon
sudo bash scripts/bootstrap-server.sh                    # 装 nginx + certbot + 防火墙
sudo bash scripts/install-site.sh <域名> <证书邮箱>       # 装站点 + Let's Encrypt 证书
```

走 **Caddy 路线**时跳过上面两条 nginx 命令，改为把 `deploy/Caddyfile.site` 的站点块合并进现有 Caddyfile（注意 Docker 要挂载 `/srv/haorizon/public`），然后 reload Caddy。

### 3. 本机配置 + 首次发布

```bash
cp deploy.env.example deploy.env     # 填 SITE_HOST（公网 IP）、SITE_USER、SITE_DOMAIN
./scripts/set-domain.sh 你的域名      # 替换页面里的占位域名
git commit -am "配置域名"
./scripts/deploy.sh
```

`deploy.sh` 做三件事：推送 → 服务器 `git fetch + reset --hard` → `curl` 探活。

## 日常更新

```bash
# 改 public/ 下的文件
git add -A && git commit -m "说明这次改了什么"
./scripts/deploy.sh
```

发布是覆盖式的（`reset --hard`），所以**服务器上的文件永远等于 git 里的版本**——不要在服务器上直接改文件。

## 回滚

```bash
ssh ubuntu@<IP>
cd /srv/haorizon
git log --oneline          # 找到上一个好版本
git reset --hard <commit>
```

静态站回滚不需要重启任何服务，刷新即生效。

## 排查表

| 现象 | 多半是 | 怎么查 |
|---|---|---|
| 浏览器转圈 / 连接被拒 | 安全组或 ufw 没放行 | `sudo ufw status`；控制台查安全组 |
| 打开是 nginx 默认页 | 站点配置没启用 | `ls /etc/nginx/sites-enabled/` |
| 403 Forbidden | nginx 读不到文件（权限/路径） | `sudo -u www-data ls /srv/haorizon/public` |
| 证书报错 / NET::ERR_CERT | DNS 还没生效就申请了证书 | `dig +short 域名`，生效后重跑 certbot |
| 改了没生效 | 缓存或没发布 | 强制刷新；`git -C /srv/haorizon log -1` 看服务器版本 |
| 大陆访问弹备案提示 | 未备案 | 只能备案，或把站点放到境外/香港节点 |

## 接下来要一起定的

- [ ] 域名、证书邮箱、站点标题（现在是 Hao-rizon）
- [ ] 页脚还写着 `PROTOTYPE`，正式版是否保留
- [ ] 「项目与作品」两个条目要不要各自的详情页（那会从单页变成多页 + 内容结构）
- [ ] 设备探针接真实数据（现在是前端随机演示）
- [ ] 私有区（服务入口 / 设备指标）是否要做登录，还是干脆不公开
- [ ] 分享卡片图 `assets/og.png` 已从真实页面截好（1200×630），换版式时记得重拍
