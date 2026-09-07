# 工程与版本管理

项目根目录为 `J:\Project\rainrot`。根目录是桌面版 Godot 工程，`WebVersion/project` 是独立网页版工程；两者的源码、必要资源和许可文件均纳入 Git。启动与构建脚本按自身位置定位工程，可以移动整个项目目录。

Git 不跟踪 Godot 缓存、本机运行环境、日志、演示截图、交付 ZIP、网页导出产物及下载的导出模板。这些现有文件仍保留在本机。网页的自定义入口、样式和适配脚本继续跟踪。

新克隆工程后，使用 Godot 4.7.1 打开相应的 `project.godot`，由编辑器重新导入资源。构建网页版前，在根目录运行以下命令下载对应的官方网页导出模板：

```powershell
python WebVersion/tools/fetch_web_templates.py
powershell -ExecutionPolicy Bypass -File WebVersion/Build_Web.ps1
```

如 Godot 或 Python 安装位置不同，可通过 `Build_Web.ps1` 的 `-Godot`、`-Python` 参数指定。下载模板需要网络访问。网页运行、存档与部署说明见 `WebVersion/README_网页版.md`。

远程仓库：https://github.com/semibluff888/rainrot ，默认分支为 `main`。

## 网页自动部署

公网地址：https://semibluff888.github.io/rainrot/

推送到 `main` 后，GitHub Actions 的 `Deploy web game to GitHub Pages` 工作流会下载固定版本的 Godot 4.7.1 和经过 SHA-256 校验的网页模板，导入并导出 `WebVersion/project`，生成完整网站，再部署到 GitHub Pages。构建失败时保留上一次成功部署的网站。

进度与错误日志：https://github.com/semibluff888/rainrot/actions/workflows/deploy-pages.yml 。也可以在该页面选择 `Run workflow` 手动重新发布。仓库 Settings → Pages 的 Source 使用 `GitHub Actions`。

网页版是独立工程。游戏内容更新请修改 `WebVersion/project`；网页外壳修改 `WebVersion/site`。仅修改根目录桌面版不会自动移植到网页版。修改后提交并推送到 `main` 即可，无需提交 `.godot`、WASM、PCK 或 ZIP，也无需本机启动服务器。

首次构建和发布需要等待 Actions 完成；访问后如仍显示旧内容，可以强制刷新。网页版存档属于当前浏览器和网址，首次从 localhost 改为公网地址时，请使用网页上的备份、导入功能转移存档。
