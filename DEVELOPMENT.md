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

## 桌面版打包与发布

桌面版采用根目录的 Godot 工程，Windows x64 导出配置保存在 `export_presets.cfg`，保持 Forward+ 画质。玩家下载入口：https://github.com/semibluff888/rainrot/releases/latest 。

Windows 本地构建（Godot 路径替换为自己的安装路径）：

```powershell
python tools/fetch_windows_templates.py
python tools/build_windows.py --godot D:/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe
```

下载工具只提取固定 Godot 4.7.1 官方模板中的 Windows x64 文件，并核对 `tools/windows-templates.json` 中的 SHA-256。工具链保存在 `.runtime/windows-toolchain`，不提交 Git。`--record` 仅供维护者在确认官方模板来源后更新固定校验值，日常构建不要使用。

构建脚本会导出真正的独立程序，再对这个程序执行 55 项集成检查和怪物检查。测试存档独立保存在 `.runtime/windows-build/userdata`。检查成功后生成 `delivery/RAINROT-Windows-x64.zip` 和 SHA-256 校验文件。玩家包仅包含运行文件、说明与许可证，不含测试存档、录像或工程缓存。

后续正式发布：先更新游戏和 `docs/WINDOWS_RELEASE_NOTES.md`，提交并推送 `main`，再创建新的版本标签，例如：

```powershell
git tag v0.1.1
git push origin v0.1.1
```

`Build and release Windows game` 工作流会在 Windows runner 上重新构建、检查，并把 ZIP 和校验文件发布到该标签的 GitHub Release。每次使用新的版本号，不覆盖旧版标签。仅推送 `main` 不会产生正式桌面版 Release；如需只检查打包，可在 Actions 中手动运行该工作流，下载构建 artifact。
