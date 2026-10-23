# Hao-rizon — 个人主页

单页静态站：纯 HTML / CSS / JS，**零依赖、零构建**。改了文件就是改了网站，服务器只负责把它发出去。

- 线上地址：<https://www.hao-rizon.com>（裸域 `hao-rizon.com` 由 Caddy 301 跳到 www）
- 服务器：腾讯云 CVM，域名已备案，解析到 `129.204.31.88`
- 入口：**只有 Caddy 一个**，独占 80/443 并自动申请 / 续期证书
- 当前版本：v0.1「赤色构成」原型（`public/index.html`）
- `archive/cubism/` 是上一版方案（碎面 / AARON.HUB），只作存档，不参与部署

## 为什么是 Caddy 不是 nginx

这台机器上迟早不止一个站点（同步中枢、MARS、其他服务）。**80/443 谁先占谁赢**，所以边缘只留一个进程：

```
                       ┌─ www.hao-rizon.com   → /srv/haorizon/public（本仓库，静态文件）
互联网 ── 80/443 ── Caddy ├─ hao-rizon.com       → 301 到 www
                       └─ 以后：sync.hao-rizon.com → reverse_proxy 127.0.0.1:5984
```

新服务只加站点块，不再新装 web 服务器。Caddy 自动签证书、自动续期，没有 certbot 定时器要照看。

## 目录

```
public/              ← 网站根目录（Caddy 只发这里面的文件）
  index.html
  404.html
  robots.txt
  assets/            favicon.svg、og.png（1200×630 分享图）
deploy/
  Caddyfile          服务器唯一入口配置（/etc/caddy/Caddyfile 软链到这里）
scripts/
  bootstrap-server.sh 服务器首次：装 Caddy + git + ufw
  install-site.sh     服务器首次：软链配置 + 校验 + 重载
  deploy.sh           本机：push → 服务器拉取 → 探活
  remote-pull.sh      deploy.sh 通过 ssh 送过去执行的脚本
  set-domain.sh       换域名时批量替换（页面 meta + Caddyfile）
deploy.env.example    本机部署参数模板（复制成 deploy.env）
```

## 本地预览

```bash
python -m http.server 8080 --directory public
# http://localhost:8080/
```

必须用 HTTP 服务打开，不要双击 `file://`——`/assets/...` 这类根路径在 `file://` 下会失效。

## 上线（一次性）

顺序不能颠倒：**先放行端口 → 再装 Caddy → 站点才有证书**。Let's Encrypt 要在域名可达的 80/443 上做校验，端口不通就签不出证书。

### 1. 放行端口（腾讯云控制台，只能手点）

安全组入站规则需要 TCP **80** 和 **443** 对 `0.0.0.0/0` 放行。本机 ufw 是第二道，`bootstrap-server.sh` 会开。

> 2026-10-23 从本机实测：22 通；80 返回 connection refused（说明包能到主机、只差监听进程，安全组大概率已放行 80）；**443 超时（大概率安全组没放行，需要去加规则）**。

### 2. 服务器准备

```bash
ssh ubuntu@129.204.31.88
sudo mkdir -p /srv/haorizon && sudo chown "$USER":"$USER" /srv/haorizon
git clone https://github.com/AaronOvO-LLL/hao-rizon-dashboard.git /srv/haorizon
cd /srv/haorizon
sudo bash scripts/bootstrap-server.sh     # 装 Caddy + 防火墙
sudo bash scripts/install-site.sh         # 软链配置 + 签发证书 + 探活
```

> `git clone` 用你自己的用户执行，**不要 `sudo`**——否则 `/srv/haorizon` 归 root，之后 `deploy.sh` 推不进去。

### 3. 本机配置 + 首次发布

```bash
cp deploy.env.example deploy.env      # 填 SITE_USER（你的登录用户名）
./scripts/deploy.sh
```

## 日常更新

```bash
# 改 public/ 下的文件
git add -A && git commit -m "说明这次改了什么"
./scripts/deploy.sh
```

发布是覆盖式的（`git reset --hard`）：**服务器上的文件永远等于 git 里的版本**，不要在服务器上直接改文件。

- 改 `public/` 里的文件 → 秒级生效，Caddy 直接从工作目录读，不用重启
- 改 `deploy/Caddyfile` → `deploy.sh` 检测到变更会先 `caddy validate`，通过才 reload，失败则保持旧配置继续服务

## 回滚

```bash
ssh ubuntu@129.204.31.88
cd /srv/haorizon
git log --oneline
git reset --hard <commit>
```

静态站回滚不需要重启任何服务，刷新即生效。

## 排查表

| 现象 | 多半是 | 怎么查 |
|---|---|---|
| 连接被拒 / 一直转圈 | 安全组或 ufw 没放行 | 控制台看安全组；`sudo ufw status` |
| 证书签不下来 | 域名没解析到本机，或 443 被拦 | `dig +short www.hao-rizon.com`；`sudo journalctl -u caddy -n 50` |
| 403 / 空白 | caddy 用户读不到文件 | `sudo -u caddy ls /srv/haorizon/public` |
| 改了没生效 | 没发布或浏览器缓存 | `git -C /srv/haorizon log -1`；强制刷新 |
| 502（未来接反代时） | 上游服务没起 | `systemctl status <服务>`；`curl 127.0.0.1:<端口>` |
| 大陆访问弹备案提示 | 未备案 | 你已经备案了；若换域名需重新备案 |

## 接下来要一起定的

- [ ] 页脚还写着 `PROTOTYPE`，正式版是否保留
- [ ] 「项目与作品」两个条目要不要各自的详情页（会从单页变成多页 + 内容结构）
- [ ] 设备探针接真实数据（现在是前端随机演示）
- [ ] 私有区（服务入口 / 设备指标）是否要做登录，还是干脆不公开
- [ ] 换版式时重拍 `assets/og.png`（1200×630）
