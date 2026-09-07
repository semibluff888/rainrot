"""Build an asset comparison using public publisher preview URLs, without downloading images."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
models = {}
for filename in ("candidates.json", "final-extra.json"):
    for model in json.loads((ROOT / filename).read_text(encoding="utf-8-sig")):
        models[model["uid"]] = model

designs = [
    dict(uid="3d3fc31eddaa409a8f2df564823154e1", title="笑面病患", english="THE GRINNING PATIENT",
         role="走廊主敌人", tag="首选 · 心理压迫", color="#bd665d",
         silhouette="空洞眼窝、固定露齿的笑脸，头部前倾，手臂低垂。远处仍像一个人，靠近后表情完全没有回应。",
         direction="加上破损病号服、编号腕带和皮肤潮湿感；保留面部明暗反差，减少鲜红色面积。",
         encounter="先让它站在走廊尽头侧身不动；听到脚步后慢慢转头，再以不规律步伐靠近，接近时突然加速。",
         readiness="页面记录 1 段动画；尚不能确认包含行走、攻击、受击和死亡动作。需检查骨骼，并补齐动作集。",
         work="中等", recommendation="五个里最适合成为第九病区的标志性主敌人。"),
    dict(uid="2bc6e1cac98e458a824691009ef2433c", title="多肢护士", english="THE SPLINTERED NURSE",
         role="药房 / 停尸间精英敌人", tag="人体畸变", color="#91aaa8",
         silhouette="黑发遮面、残破的医疗服，身体向下分出尖锐的多肢轮廓。人体的熟悉感被肢体结构破坏。",
         direction="改成疗养院旧式护理制服，头部增加遮光面罩和患者标签；降低鲜血饱和度，强调皮肤和布料质感。",
         encounter="关灯后先响起尖肢触地声；它从药柜侧面缓慢探出，攻击前用肢体撑高身体。",
         readiness="作者明确标注完整骨骼绑定；页面动画数为 0，需要专门制作多肢行走和攻击。",
         work="较高", recommendation="医疗场景关联最强，肢体变形也最明显。"),
    dict(uid="06d2b90a1e24471283f6aaac748db1c9", title="长臂爬行者", english="THE UNDERBED CRAWLER",
         role="病房伏击敌人", tag="推荐搭配 · 低位威胁", color="#bca682",
         silhouette="身体紧贴地面，前臂和手指异常修长，口部突出。它的攻击方向会落在玩家习惯观察的高度以下。",
         direction="把黄绿色皮肤改为失血般灰白，加入实验编号、输液固定痕迹和局部湿润材质。",
         encounter="床下先出现手指和摩擦声；玩家走过后，它从身侧快速拖行出来。伏击前保留可辨识的声音提示。",
         readiness="作者标注已绑定骨骼，含 2K 基础色、粗糙度和法线贴图；页面动画数为 0，需制作爬行与扑击。",
         work="较高", recommendation="适合与笑面病患搭配，让玩家同时担心前方和脚边。"),
    dict(uid="417f6ff2d90043a7ab061d560801be93", title="畸变实验犬", english="THE FAILED HOUND",
         role="地下实验室 / 后院追击敌人", tag="生化实验感", color="#9b9e77",
         silhouette="犬形头颅与巨大的牙床，背部隆起，四肢比例失衡。还保留动物轮廓，但行动姿态明显异常。",
         direction="加入断裂项圈、植入标签和实验拘束带；调整肌肉与皮肤的光泽，统一为地下实验室的冷色调。",
         encounter="先在隔离门后喘息撞门；逃生时从侧方切入追击。用急促爪声提示加速，保留侧向闪避空间。",
         readiness="资产标题标注 Rig，页面记录 1 段动画；完整跑动、扑咬和转向动作需要下载后核对。",
         work="中等至较高", recommendation="最接近生化实验失败产物的方向，适合强调追逐压力。"),
    dict(uid="10bb4cf49d304d64afd2b829666f6caf", title="巨口蛛体", english="THE GAPEWEAVER",
         role="地下区域特殊怪物", tag="虫形恐惧 / 强轮廓", color="#9b8db0",
         silhouette="巨大的口器、膨胀腹部和细长蛛足，脸部与虫体混合。腿部在墙上的投影会先于本体出现。",
         direction="减弱甲壳的奇幻感，改成潮湿的灰白组织；加上实验固定夹与编号，缩放到现有地下路线可容纳的体型。",
         encounter="先从管线间投下长腿影子，再缓慢横穿出口；玩家启动设备后，它才开始追击。",
         readiness="页面记录 2 段动画、约 6.8 万面；需要核对动作内容，处理蛛足运动、转弯宽度与碰撞。",
         work="高", recommendation="适合接受更强虫形怪物风格的选择，场景适配工作最多。"),
]

for index, design in enumerate(designs, 1):
    model = models[design["uid"]]
    design.update(number=index, source_name=model["name"], author=model["author"],
                  source=model["url"], image=max(model["thumbnails"]["images"], key=lambda i: i["width"])["url"],
                  faces=model["faces"], animation_count=model["animationCount"],
                  license=model["license"], downloadable=model["isDownloadable"])

(ROOT / "options.json").write_text(json.dumps(designs, ensure_ascii=False, indent=2), encoding="utf-8")
e = html.escape
cards = "\n".join(
    f'<button class="card" data-index="{i}" aria-pressed="{str(i == 0).lower()}"><img src="{e(d["image"])}" alt="{e(d["source_name"])}，{e(d["author"])} 原作预览"><span class="card-line"><b>0{d["number"]}</b><strong>{d["title"]}</strong></span><span class="card-role">{d["role"]}</span></button>'
    for i, d in enumerate(designs)
)
payload = json.dumps(designs, ensure_ascii=False).replace("<", "\\u003c")
page = r'''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>雨蚀：第九病区 — 五个怪物方案</title>
<style>
:root{color-scheme:dark;--bg:#0c1113;--panel:#151c1e;--text:#e5e8e4;--muted:#9ba8a8;--line:#344043;--accent:#bd665d}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 90% 0,#203133 0,transparent 53%),var(--bg);color:var(--text);font:15px/1.6 "Microsoft YaHei","Segoe UI",sans-serif}main{max-width:1480px;margin:auto;padding:32px 36px 28px}header{display:flex;justify-content:space-between;align-items:end;border-bottom:1px solid var(--line);padding-bottom:20px;gap:20px}.eyebrow{font:11px/1.5 "Consolas",monospace;letter-spacing:3px;color:#9db7b5}.eyebrow b{color:#cb786b}h1{font-size:29px;font-weight:500;letter-spacing:3px;margin:5px 0 0}header p{color:var(--muted);font-size:12px;text-align:right;margin:0}nav{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px;margin:23px 0}.card{background:#151c1e;border:1px solid #2d373a;border-radius:3px;color:var(--text);padding:0 0 11px;text-align:left;cursor:pointer;overflow:hidden;transition:border-color .15s,transform .15s;min-width:0}.card:hover{transform:translateY(-3px);border-color:#8d9b9e}.card[aria-pressed=true]{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent)}.card img{width:100%;height:135px;object-fit:contain;background:#080b0c;display:block}.card-line{display:flex;align-items:baseline;gap:9px;padding:10px 12px 0}.card-line b{font:13px Consolas,monospace;color:#aebbb9}.card-line strong{font-size:14px;font-weight:500;white-space:nowrap}.card-role{font-size:11px;color:var(--muted);display:block;padding:3px 12px 0}.detail{display:grid;grid-template-columns:1.12fr 1fr;border:1px solid var(--line);background:linear-gradient(120deg,#172023,#11181a);border-radius:3px;overflow:hidden}.visual{display:flex;flex-direction:column;background:#080b0c;min-width:0}.image-wrap{display:grid;place-items:center;flex:1;position:relative;min-height:365px}.image-wrap img{width:100%;height:390px;object-fit:contain}.stamp{position:absolute;left:18px;top:15px;font:10px Consolas,monospace;letter-spacing:2px;color:#a8b8b5;background:#0c1113bb;padding:4px 8px;border:1px solid #34403e}.credit{font-size:11px;color:#91a29f;border-top:1px solid #25302f;padding:11px 17px}.credit span{display:block}.content{padding:25px 28px}.role{color:var(--accent);font-size:11px;letter-spacing:2px}.content h2{font-size:28px;font-weight:500;letter-spacing:3px;line-height:1.3;margin:9px 0 2px}.en{font:10px Consolas,monospace;letter-spacing:2px;color:#879c9d}.lead{font-size:14px;line-height:1.8;margin:19px 0 15px}.proposal{display:grid;gap:11px}.proposal p{font-size:12px;color:#b2c0bd;margin:0;line-height:1.8}.proposal b{display:block;font-size:10px;color:#e1e5df;letter-spacing:2px;margin-bottom:1px}.links{display:flex;flex-wrap:wrap;gap:10px;margin-top:21px}.links a{font-size:11px;letter-spacing:1px;text-decoration:none;border:1px solid #53635f;padding:8px 14px;color:#dce6df}.links a:first-child{background:#d1d8cb;color:#142020;border-color:#d1d8cb}.readiness{display:grid;grid-template-columns:170px 1fr;gap:25px;padding:18px 21px;border:1px solid var(--line);border-top:0;background:#11191b;font-size:12px;color:#aebbb7}.readiness strong{font-size:13px;font-weight:500;display:block;color:#dce3da}.readiness p{margin:0}.readiness .metric{color:#8fa7a6;font:10px/1.8 Consolas,monospace;margin-top:5px}.note{font-size:11px;color:#8fa09e;margin:16px 0 0;line-height:1.9}.note a{color:#b7cebd}.recommendation{color:#c6d4c9;font-size:12px;margin:14px 0 0}button:focus-visible,a:focus-visible{outline:2px solid #d5ead3;outline-offset:4px}@media(min-width:1400px){.card img{height:170px}}@media(max-width:850px){main{padding:20px}header{align-items:start}h1{font-size:23px}header p{max-width:150px}nav{grid-template-columns:repeat(3,1fr)}.detail{grid-template-columns:1fr}.image-wrap{min-height:260px}.image-wrap img{height:340px}.readiness{grid-template-columns:1fr;gap:8px}}@media(max-width:500px){nav{grid-template-columns:repeat(2,1fr)}.content{padding:20px}.card img{height:120px}header{display:block}header p{text-align:left;max-width:none;margin-top:10px}}
</style></head><body><main>
<header><div><div class="eyebrow"><b>RAINROT</b> / WARD 09 · CREATURE STUDIES</div><h1>五种恐惧，选择它的样子。</h1></div><p>《雨蚀：第九病区》怪物方案<br>点击卡片切换 · 回复编号即可选择</p></header>
<nav aria-label="五个怪物方案">__CARDS__</nav>
<section class="detail" aria-live="polite"><div class="visual"><div class="image-wrap"><span class="stamp">SOURCE ASSET / 原作预览</span><img id="hero" alt=""></div><div class="credit"><span id="source-name"></span><span id="credit"></span></div></div><div class="content"><div class="role" id="role"></div><h2 id="title"></h2><div class="en" id="english"></div><p class="lead" id="silhouette"></p><div class="proposal"><p><b>拟议改造</b><span id="direction"></span></p><p><b>拟议遭遇</b><span id="encounter"></span></p></div><div class="links"><a id="large" target="_blank" rel="noopener noreferrer">放大原作图片 ↗</a><a id="source" target="_blank" rel="noopener noreferrer">作者页面 / 3D 预览 ↗</a></div></div></section>
<section class="readiness"><div><strong id="work"></strong><div class="metric" id="metrics"></div></div><p id="readiness"></p></section>
<p class="recommendation" id="recommendation"></p>
<p class="note">五个模型页面均标注可下载、<a href="https://creativecommons.org/licenses/by/4.0/" target="_blank" rel="noopener noreferrer">CC BY 4.0</a>：允许商用与改编，须署名、附许可链接并说明修改。核对日期：2026-09-07。<br>以上图片是作者的线上资产预览，图片加载需要联网；名称、改造和遭遇是本项目的设计提案。尚未下载模型或在 Godot 中验证，演示动画数量不代表完整战斗动作集。</p>
</main><script>const options=__DATA__;const text=(id,value)=>document.getElementById(id).textContent=value;function show(i){const d=options[i];document.documentElement.style.setProperty('--accent',d.color);document.querySelectorAll('.card').forEach((c,j)=>c.setAttribute('aria-pressed',String(i===j)));const hero=document.getElementById('hero');hero.src=d.image;hero.alt=d.title+' — '+d.source_name+'，'+d.author+' 原作预览';['title','english','silhouette','direction','encounter','readiness','recommendation'].forEach(k=>text(k,d[k]));text('role','0'+d.number+' / '+d.tag);text('source-name',d.source_name);text('credit','原作者：'+d.author+' · CC BY 4.0');text('work','接入工作量：'+d.work);text('metrics',d.faces.toLocaleString()+' FACES / '+d.animation_count+' PREVIEW CLIP(S)');document.getElementById('large').href=d.image;document.getElementById('source').href=d.source;}document.querySelectorAll('.card').forEach(c=>c.addEventListener('click',()=>show(Number(c.dataset.index))));show(0);</script></body></html>'''
(ROOT / "index.html").write_text(page.replace("__CARDS__", cards).replace("__DATA__", payload), encoding="utf-8")

lines = ["# 《雨蚀：第九病区》五个怪物方案", "", "核对日期：2026-09-07。图片为作者资产预览；中文名称与遭遇设计为本项目提案。未下载、导入或修改游戏怪物。", "",
         "所有入选页面均标注可下载、CC BY 4.0，允许商用与改编，须保留作者署名、来源和许可链接，说明修改。动画数量来自公开模型 API，不保证已具备完整战斗动作。", ""]
for d in designs:
    lines += [f'## {d["number"]}. {d["title"]}', "", f'![{d["source_name"]} 原作预览]({d["image"]})', "",
              f'原作：[{d["source_name"]}]({d["source"]})，作者 **{d["author"]}**。', "",
              f'外观：{d["silhouette"]}', "", f'拟议改造：{d["direction"]}', "", f'拟议遭遇：{d["encounter"]}', "",
              f'接入条件：{d["readiness"]} 页面面数 {d["faces"]:,}。工作量：{d["work"]}。', "",
              f'建议：{d["recommendation"]}', "",
              f'许可：[CC BY 4.0]({d["license"]["url"]})。公开元数据：https://api.sketchfab.com/v3/models/{d["uid"]}', ""]
lines += ["## 接入前核对", "", "选定后获取原作者模型，检查骨骼层级、贴图和动画；优先整理为 glTF/GLB 导入 Godot。现有 enemy.gd 使用命名节点驱动程序动画，替换为骨骼角色时需要适配 AnimationPlayer/AnimationTree，不能只替换模型文件。", "", "爬行和多肢模型需要额外检查低位攻击、转弯半径、楼梯、门框与安全区规则；完成后再用现有关卡验证性能和可通行性。", "", "此目录仅为方案研究，未把这些模型加入正式资产许可清单。"]
(ROOT / "README.md").write_text("\n".join(lines), encoding="utf-8")
print(json.dumps([{k:d[k] for k in ('number','title','source_name','source','author','image')} for d in designs],ensure_ascii=False,indent=2))
