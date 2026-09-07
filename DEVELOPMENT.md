# 工程与版本管理

项目根目录为 `J:\Project\ResidentEvil`。根目录是桌面版 Godot 工程，`WebVersion/project` 是独立网页版工程；两者的源码、必要资源和许可文件均纳入 Git。

Git 不跟踪 Godot 缓存、本机运行环境、日志、演示截图、交付 ZIP、网页导出产物及下载的导出模板。这些现有文件仍保留在本机。网页的自定义入口、样式和适配脚本继续跟踪。

新克隆工程后，使用 Godot 4.7.1 打开相应的 `project.godot`，由编辑器重新导入资源。构建网页版前，在根目录运行以下命令下载对应的官方网页导出模板：

```powershell
python WebVersion/tools/fetch_web_templates.py
powershell -ExecutionPolicy Bypass -File WebVersion/Build_Web.ps1
```

如 Godot 或 Python 安装位置不同，可通过 `Build_Web.ps1` 的 `-Godot`、`-Python` 参数指定。下载模板需要网络访问。网页运行、存档与部署说明见 `WebVersion/README_网页版.md`。

当前仅建立本地 Git 仓库；远程托管需要另行配置。
