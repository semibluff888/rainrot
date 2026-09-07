# 雨蚀：第九病区 / RAINROT · WARD 09

一款原创的第一人称单机恐怖解谜游戏。雨夜进入失联的圣维罗妮卡疗养院，调查留下的档案，恢复西翼供电，进入地下终止培养循环，带着证据逃离。

本仓库同时包含桌面版和独立网页版。网页版的构建、启动与部署见 [网页说明](WebVersion/README_网页版.md)；从 Git 克隆后的准备步骤见 [开发说明](DEVELOPMENT.md)。网页导出文件、演示视频及交付 ZIP 由工具生成，不随源码仓库分发。

## 玩家下载

[下载 Windows 桌面版](https://github.com/semibluff888/rainrot/releases/latest)：选择 `RAINROT-Windows-x64.zip`，完整解压后运行 `RAINROT.exe`，无需安装 Godot 或 Python。需要 Windows 10/11 64 位及支持 Vulkan 的显卡。

[直接玩网页版](https://semibluff888.github.io/rainrot/) · [桌面版发布流程](DEVELOPMENT.md#桌面版打包与发布)

## 从源码开始游戏

**双击本目录的 `Launch.cmd`。** 首次进入后选择「进入疗养院」。建议使用耳机。

启动脚本已配置当前电脑的 Godot：

`D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe`

双击 `OpenEditor.cmd` 可打开完整工程。也可在 Godot 4.7.1 中导入 `project.godot` 后按 F5。场景已经制作并保存在 `scenes/hospital.tscn`；正常运行不需要 Python、联网或重建关卡。

查看本次怪物接入效果：打开 `captures/RAINROT_Enemy_Demo.mp4`，或双击 `Showcase.cmd` 播放 Godot 实机演示。截图与接入说明在 `MONSTER_INTEGRATION.md`。

当前交付使用本机 Godot 运行，无须导出模板。换到其他电脑时，安装 Godot 4.7.1 并修改启动脚本内的路径。请保留整个工程目录，不要只复制启动脚本。

## 操作

| 按键 | 功能 |
| --- | --- |
| WASD / 鼠标 | 移动 / 观察 |
| Shift / Ctrl | 冲刺 / 蹲伏 |
| E / F | 交互 / 手电 |
| 左键 / 右键 / R | 射击 / 瞄准 / 换弹 |
| Tab | 背包；点击急救敷料恢复生命 |
| J | 档案、楼层示意图与可选渐进提示 |
| Esc | 暂停或关闭界面 |
| F11 | 全屏与窗口切换 |

视听设置可调鼠标灵敏度、亮度、音量、镜头晃动和三档画质。菜单中可以查看完整操作说明。检查关键物件时按住左键拖动旋转。

## 体验内容

- 八个主要空间、双走廊环路和通往地下实验室的实体楼梯。
- 三个连贯谜题：四路配电、护士药柜、病理标本归档。答案来自可反复查阅的中文档案。
- 笑面病患、多肢护士及强化护士长。病患先转头警觉，再拖步接近并短暂加速；护士以六肢交替支撑，刺击前摇 0.75 秒，可击杀或绕行；最终护士长不能击杀，可被枪击打断。头部与躯干命中随骨骼移动。
- 六格补给背包，关键道具独立保管；档案日志、物品旋转检查、可选提示和楼层图。
- 值班室安全区、录音机手动存档、章节自动记录、死亡重试、完整结局。
- 实时灯光、阴影、SSAO、SSIL、屏幕空间反射、体积雾、雨窗、雷光、积水、灰尘和动态环境声。

这是一个完整的短章节。首次调查的设计目标为 20—30 分钟，实际长度取决于阅读、探索和解谜速度；尚未以陌生玩家盲测验证这个时长。已经知道全部答案、跳过阅读的自动化路线约需 2 分 11 秒，这个数字用于验证连通性，不代表首次游玩时长。

## 保存与恢复

正式存档位置：`%APPDATA%\Godot\app_userdata\雨蚀：第九病区 - RAINROT\`；也可在 Godot 的「项目 → 打开用户数据文件夹」中打开。

- `progress.json`：最近的安全区或章节记录，写入后原子替换。
- `settings.cfg`：视听设置。
- 最终控制台在释放追逐者之前保存，可重新尝试逃生。
- 继续游戏会恢复位置、生命、弹药、补给、钥匙、档案、已拾取物、死去的敌人和门。存活敌人从对应章节的巡逻位置重新开始。
- 点击「进入疗养院」开始新的调查，并覆盖最近记录。没有自动云同步。

开发测试使用项目内 `.runtime` 中的独立用户目录，且使用 `test_progress.json` / `capture_progress.json`，不覆盖正式玩家记录。

## 工程结构

- `scenes/hospital.tscn`：可在编辑器中修改的完整关卡；`scenes/enemies/`：三种角色配置、原模型可编辑场景、骨骼关键帧与静态培养罐模型。
- `scripts/`：玩家、敌人、统一交互、谜题/进度、存档、界面和声音。
- `assets/`：11 组 CC0 材质/模型、两款 CC BY 4.0 角色、中文字体及 25 个原创音频文件；来源见 `ASSET_LICENSES.md`。
- `materials/` 与 `shaders/`：材质、环境和预烘焙导航网格。
- `tools/build_level.gd`：可复现的关卡生成器。它会覆盖生成的场景；手工编辑关卡后不要直接重跑，先保存副本。
- `tests/`：状态与实景集成检查，以及不传送玩家的连续通关测试。
- `captures/`：Godot 实机截图与测试报告；`logs/`：本次验证日志。

## 开发验证命令

在项目根目录的 PowerShell 中运行；请把下面的 Godot 路径替换为自己的安装位置。正常玩游戏不需要这些命令。

```powershell
$godotExe = 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
& $godotExe --headless --editor --import --path .
& $godotExe --headless --fixed-fps 60 --path . -- --test
& $godotExe --headless --fixed-fps 60 --path . -- --enemy-test
& $godotExe --headless --fixed-fps 60 --quit-after 60000 --path . -- --walkthrough
& $godotExe --headless --fixed-fps 60 --quit-after 60000 --path . -- --walkthrough --pacifist
& $godotExe --path . -- --capture
& $godotExe --path . -- --benchmark
& $godotExe --path . --fixed-fps 30 -- --enemy-showcase
```

重新生成场景：`& $godotExe --headless --path . --script res://tools/build_level.gd`。

可选资源准备工具需要 Python、NumPy；`tools/fetch_assets.py` 仅用于重新获取 CC0/OFL 资源，`tools/make_audio.py` 可重建原创声音。已下载资源在正常运行时完全离线使用。
