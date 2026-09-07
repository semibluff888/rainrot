# 笑面病患与多肢护士 · 接入交付

两款角色使用用户选定的原作者资产。最终逃生使用强化多肢护士，四个敌人 ID 和版本 1 存档保持兼容。

## 直接查看

- [实机演示视频](captures/RAINROT_Enemy_Demo.mp4)：角色近景、护士警觉及枪击打断、实际楼梯与最终逃生。
- [笑面病患 · 走廊](captures/12_smily_corridor.png)
- [多肢护士 · 停尸间](captures/13_nurse_morgue.png)
- [护士刺击](captures/14_nurse_stab.png)
- [病房暖光](captures/15_nurse_ward.png)
- [强化护士 · 地下红色警报](captures/16_elite_laboratory.png)
- [普通遭遇](captures/17_nurse_encounter.png)
- [最终追逐](captures/18_final_pursuit.png)

双击 `Launch.cmd` 开始游戏；`Showcase.cmd` 播放可复现的实机演示，使用独立测试存档。演示前半段为固定机位角色展示，后半段使用实际敌人 AI、输入与碰撞。完整流程是否可通关以两个连续通关报告为准。

## 章节安排

| ID | 角色 | 触发 |
| --- | --- | --- |
| west_patient | 笑面病患 | 恢复西翼供电 |
| east_patient | 普通多肢护士 | 首次打开冷库，在停尸间出现 |
| ward_patient | 笑面病患 | 获得实验室通行卡后 |
| the_orderly | 强化多肢护士 | 终止实验，沿楼梯与回廊追到出口 |

护士普通攻击的前摇／刺击／收招为 0.75／0.18／0.85 秒，伤害 28。强化版为 0.70／0.17／0.70 秒，保持追逐速度 3.6 m/s、伤害 32；枪击会打断，其生命不减少。病患有首次警觉、声音预告和短距离加速。攻击检查距离、朝向和遮挡，每次只结算一次；受击或死亡立即取消尚未发生的伤害。

## 编辑模型与动作

`scenes/enemies/` 的三个 `*_visual.tscn` 为展开的可编辑节点树，包含原模型网格、骨架、BoneAttachment3D、AnimationPlayer 与动画关键帧。调整数值使用 `smily.tres`、`nurse.tres`、`nurse_elite.tres`。动画为原地动作，位移来自 CharacterBody3D；移动动画按实际速度调节。阅读、背包、暂停时停止动画时钟、AI、伤害和怪物空间音效。

护士在作者 25 个导入骨骼基础上增加 12 个关节，六条下肢各有基部及末端关节，共 37 个骨骼；针刃随对应手骨运动。笑面病患保留 46 个骨骼。两款均提供 idle、alert、walk、run、attack、stun、dead；另有 raise、stab、recover 可编辑分段。游戏中的护士攻击使用完整 attack 曲线，时间与实际伤害窗口对齐。

高／中画质使用最高 2048px 贴图，低画质使用最高 1024px 贴图。未改做病号服，未加入其他爬行者资产。护士保留原作以头发遮盖头部、破损服装及多肢的造型。

重新生成流程（会覆盖生成文件，手工编辑前请另存）：

1. `tools/prepare_enemy_models.py`：从已下载官方 GLB 提取资源及贴图。
2. `tools/rig_nurse_limbs.py`：增加六条下肢的独立关节和权重。
3. Godot `--headless --editor --import --path .`。
4. Godot `--headless --path . --script tools/build_enemy_visuals.gd`：生成可编辑角色与动作。
5. Godot `--headless --path . --script tools/build_level.gd`：生成培养罐实例与导航。
6. `tools/update_enemy_manifest.py`：更新修改记录和校验值。

原包获取后，正常运行完全离线。作者、链接、许可与修改记录见 `ASSET_LICENSES.md`、各模型目录的 `SOURCE.json` 和 `assets/manifest.json`。验证结果与实际性能见 `VALIDATION.md`。

完整工程包 `delivery/RAINROT_Monsters_2026-09-07.zip` 附带 `source_archives/`，保存两款官方 GLB 与原始 ZIP；资源准备工具也支持从该目录重新生成。解压后双击 `Launch.cmd`，首次运行会自动导入资源。
