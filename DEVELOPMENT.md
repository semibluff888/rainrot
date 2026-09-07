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

## 后续网页部署

先按上述步骤生成网页，再将 `WebVersion/site` 作为网站发布目录。仓库中的 `site` 仅保存网页入口与自定义样式，不包含生成的 WASM、PCK 和引擎脚本；不能把未构建的源码目录直接发布为可玩网站。

推荐使用 HTTPS 静态托管，并为 `.wasm` 设置 `application/wasm`。此版本不依赖后端或跨源隔离。单个游戏资源文件约 38 MiB，选择托管平台时需确认其单文件限制。GitHub 仓库本身不等于已开启网站托管；本次只推送源码，不自动发布网站。
