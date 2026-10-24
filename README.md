# 成本计算器 · iPhone 版（PWA）

这是可直接部署的网页 App。部署到任意 HTTPS 静态托管后，在 iPhone 上用 **Safari** 打开，点「分享 → 添加到主屏幕」，就会像 App 一样全屏运行，并且**首次打开后离线可用**。

功能：填写石头总价值和每个人的占比，自动算出每人成本；支持增删人员、导出 CSV、打印/存 PDF，数据自动保存在手机浏览器里。

## 目录内容

| 文件 | 作用 |
|---|---|
| `index.html` | 应用本体（单文件，所有逻辑都在里面） |
| `manifest.json` | PWA 配置：App 名称、图标、全屏模式 |
| `sw.js` | Service Worker，负责离线缓存 |
| `_headers` | Cloudflare Pages 用的缓存头配置（其他托管可忽略） |
| `icons/` | 主屏幕图标（iPhone 用 180×180，其余给 Android/桌面） |

## 一、部署（二选一，都免费）

### 方式 A：Cloudflare Pages（推荐，最快）

1. 打开 <https://dash.cloudflare.com/> 注册并登录（免费账号）。
2. 左侧菜单 **Workers & Pages** → **Create** → **Pages** → **Upload assets**。
3. 项目名随意填，例如 `cost-calculator`。
4. 把 **本文件夹里的所有文件**（`index.html`、`manifest.json`、`sw.js`、`_headers` 和 `icons` 文件夹）拖进上传区，点 **Deploy**。
5. 部署完得到一个网址，类似 `https://cost-calculator.pages.dev`，复制它。

### 方式 B：GitHub Pages

1. 登录 GitHub，新建一个 **Public** 仓库，例如 `cost-calculator`。
2. 进入仓库 → **Add file** → **Upload files**，把本文件夹里的所有文件（连同 `icons` 文件夹）上传，点 **Commit changes**。
3. 仓库 **Settings** → **Pages** → **Build and deployment**：Source 选 *Deploy from a branch*，Branch 选 `main` / `(root)`，点 **Save**。
4. 等 1–2 分钟，访问 `https://你的用户名.github.io/cost-calculator/`。

### 方式 C：已有服务器

把文件原样上传到任意支持静态文件的 HTTPS 站点目录（Nginx、Apache、对象存储都可以）。**必须是 HTTPS**，否则离线缓存（Service Worker）不生效。

## 二、安装到 iPhone 主屏幕

1. 用 **Safari** 打开上面的网址（iOS 的 Chrome、微信里打开不能装成 App）。
2. 点屏幕底部中间的 **分享** 按钮（方框 + 向上箭头）。
3. 选择 **添加到主屏幕**，名称会自动是「成本计算器」，点 **添加**。
4. 桌面出现蓝色 ¥ 图标，点开就是全屏 App，没有地址栏。

> 首次打开需要联网加载一次，之后断网也能正常用。如果发现还是旧版本，把手机上的 App 删掉重新添加即可。

## 三、常见问题

- **打开是空白 / 旧版本？** 部署新文件后，把 `sw.js` 第 7 行的 `CACHE_VERSION` 改成新值（例如 `cost-calc-v2`）再上传，手机端会拉取新版本。
- **数据存在哪？** 存在这台 iPhone 的 Safari 本地存储（localStorage）里，不上传服务器；删除 App、清除 Safari 网站数据会丢失。
- **换 App 名字或图标？** 改 `index.html` 里的 `<title>`、`<h1>`、`apple-mobile-web-app-title`，以及 `manifest.json` 的 `name` / `short_name`；图标替换 `icons/` 下同名图片即可。
- **能上架 App Store 吗？** PWA 不能上架 App Store。上架需要 Apple 开发者账号（99 美元/年）+ Mac/Xcode 或云构建，那需要另做原生工程。

## 四、本地预览（可选）

在电脑上直接双击 `index.html` 就能预览功能（离线缓存只在 HTTPS 下生效）。想用手机先看效果，可以在本文件夹执行：

```bash
python -m http.server 8080
```

然后手机 Safari 访问 `http://电脑的局域网IP:8080/`（电脑和手机需连同一个 Wi-Fi；此时不能离线）。
