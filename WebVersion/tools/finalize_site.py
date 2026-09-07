"""Run after each Godot export; updates exact payload sizes and gzip variants."""
from pathlib import Path
import json, re, gzip, shutil, hashlib
root=Path(__file__).resolve().parents[1]; site=root/'site'
html=(site/'game.html').read_text(encoding='utf-8')
match=re.search(r'const GODOT_CONFIG = (.*);',html)
config=json.loads(match.group(1)) if match else json.loads((site/'build-config.js').read_text(encoding='utf-8').split(' = ',1)[1].rstrip(';\n'))
config['ensureCrossOriginIsolationHeaders']=False
(site/'build-config.js').write_text('window.RAINROT_BUILD = '+json.dumps(config,ensure_ascii=False)+';\n',encoding='utf-8')
(site/'game.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>雨蚀：第九病区</title><script>location.replace("index.html"+location.search);</script><a href="index.html">进入雨蚀：第九病区</a></html>',encoding='utf-8')
shutil.copyfile(root/'project/ASSET_LICENSES.md',site/'ASSET_LICENSES.md')
shutil.copyfile(root/'project/LICENSE',site/'LICENSE')
shutil.copyfile(root/'project/assets/fonts/OFL.txt',site/'NOTO_OFL.txt')
manifest=[]
for name in ['game.wasm','game.pck','game.js']:
 p=site/name; data=p.read_bytes(); packed=gzip.compress(data,compresslevel=7,mtime=0)
 p.with_name(p.name+'.gz').write_bytes(packed)
 manifest.append({'file':name,'bytes':len(data),'gzip_bytes':len(packed),'sha256':hashlib.sha256(data).hexdigest()})
(root/'reports/build.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
