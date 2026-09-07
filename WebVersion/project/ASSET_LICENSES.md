# 资源来源与许可

## 网页移植修改 · 2026-09-07

此目录是桌面工程的独立副本。网页版将角色高档纹理限制为 1024 px，低档限制为 512 px，生成 mipmap，并以质量 0.88 压缩导入纹理。原始字体、模型几何、骨骼与动作保持原有来源及许可；原 `assets/manifest.json` 记录的是桌面上游输入，网页修改列表另见 `WebVersion/reports/asset_adaptations.json`。场景改用兼容渲染、距离雾、批量静态盒体和网页尘埃；UI、鼠标捕获和浏览器存档适配代码为本次新增。静态网页首页背景取自本项目场景截图。

本项目使用原创名称、故事、谜题、美术组合、界面、代码和原创合成声音。没有使用《生化危机》的游戏文件、人物、商标、音乐或原版关卡。

## Poly Haven · CC0 1.0

以下资源来自 Poly Haven，按 [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) 使用。许可说明：[Poly Haven 资源许可](https://polyhaven.com/license)。获取日期：2026-09-06。

| 资源 | 用途 | 来源 |
| --- | --- | --- |
| blue_plaster_weathered | 老化的绿色墙裙、门及部分布料底材 | https://polyhaven.com/a/blue_plaster_weathered |
| damaged_plaster | 剥落墙面、顶棚、床垫 | https://polyhaven.com/a/damaged_plaster |
| concrete_floor_worn_001 | 磨损地面 | https://polyhaven.com/a/concrete_floor_worn_001 |
| brown_floor_tiles | 走廊、病房与药房地砖 | https://polyhaven.com/a/brown_floor_tiles |
| rusty_metal_sheet | 踢脚铁皮、配电与门板细节 | https://polyhaven.com/a/rusty_metal_sheet |
| dark_wood | 接待桌、工作台及长凳 | https://polyhaven.com/a/dark_wood |
| wheelchair_01 | 走廊中的轮椅 | https://polyhaven.com/a/wheelchair_01 |
| old_bed_frame | 留观病床框架 | https://polyhaven.com/a/old_bed_frame |
| portable_cassette_player | 安全区存档录音机 | https://polyhaven.com/a/portable_cassette_player |
| desk_lamp_arm_01 | 值班室台灯 | https://polyhaven.com/a/desk_lamp_arm_01 |
| portable_generator | 配电间发电机 | https://polyhaven.com/a/portable_generator |

所有下载文件、来源 URL 与 MD5 校验值保存在 `assets/manifest.json`。模型使用 glTF 及其完整依赖，表面使用 1K 漫反射、OpenGL 法线和粗糙度贴图。材质在 Godot 内调整色调、比例与物理参数。

## 字体 · SIL Open Font License 1.1

Noto Sans SC 来自 [Google Fonts 的 Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)，使用 SIL OFL 1.1。完整许可为 `assets/fonts/OFL.txt`。`regular.tres` 使用其可变字重 450，并未修改原字体文件。

## 原创内容

- 中文故事、9 份档案、谜题内容与结局。
- 疗养院建筑、门、标识、柜体、输液架、实验装置、关键物件和手枪模型。
- 旧版束缚衣模型（保留为历史资源，正式敌人已替换）；两款导入角色的游戏动作与适配代码；布料、皮肤与雨窗着色器。
- 界面、地图、配电盘、密码锁、标本终端、存档与游戏逻辑。
- 雨声、雷声、环境底噪、安全区音乐、威胁音乐、4 组脚步、枪声、受击、开门、呼吸、拾取、开关和警报，以及新增的 8 个怪物声音，共 25 个 WAV。由 `tools/make_audio.py` 确定性合成，无第三方采样。

## 角色 · Creative Commons Attribution 4.0

以下两款模型通过登录后的 Sketchfab 官方下载取得。获取日期：2026-09-07。原作者不为本项目背书。

| 作品 | 作者 | 来源 | 许可 |
| --- | --- | --- | --- |
| Smily horror monster | Bento | [原作页面](https://sketchfab.com/3d-models/smily-horror-monster-3d3fc31eddaa409a8f2df564823154e1) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Horror Mutant Bloody Nurse Gore (RIGGED) | KrimzonHaze | [原作页面](https://sketchfab.com/3d-models/horror-mutant-bloody-nurse-gore-rigged-2bc6e1cac98e458a824691009ef2433c) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

交付路径：`assets/models/enemies/smily/`、`assets/models/enemies/nurse/`，各自附有 `SOURCE.json` 与 `LICENSE.txt`。官方源包与 GLB 的 SHA256、修改后文件清单及 SHA256 记录在 `assets/manifest.json`。

修改说明：保留原始几何、UV 与主要造型；提取 glTF 贴图并提供 2K／1K 档位，基础色饱和度调整至 86%，统一粗糙度、金属度及透明裁剪；修正比例、朝向和脚底基点。在 Godot 中制作待机、警觉、行走、追击、攻击、受击、死亡等原地骨骼动作，增加随骨骼移动的命中区域。护士增加 12 个关节，重新混合六条下肢的蒙皮权重，将针刃挂接到对应手骨，并制作强化版站姿、撑高、刺击和收招。笑面病患保留原 glTF 内的作者动画，另生成适配游戏的动作及培养罐静态实例。

分发这些角色或其修改版本时，须保留作品名、作者、来源链接、CC BY 4.0 许可链接及修改说明。

本项目的原创代码与原创资源按 MIT 许可交付；第三方内容继续遵循各自的 CC0、OFL 或 CC BY 4.0 许可。
