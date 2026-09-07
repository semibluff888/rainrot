"""Optimize the separate web copy; never modifies the desktop project."""
from pathlib import Path
from PIL import Image
import json,re

ROOT=Path(__file__).resolve().parents[1]
project=ROOT/'project'
changed=[]
for role in ['smily','nurse']:
    for tier,size in [('high',1024),('low',512)]:
        for path in (project/'assets/models/enemies'/role/'textures'/tier).glob('*.png'):
            im=Image.open(path)
            if max(im.size)>size:
                before=im.size;im.thumbnail((size,size),Image.Resampling.LANCZOS);im.save(path,optimize=True)
                changed.append({'path':path.relative_to(project).as_posix(),'before':before,'after':im.size})
# Trilinear mipmaps prevent distant corridors from shimmering in WebGL.
for path in (project/'assets').rglob('*.import'):
    if path.name.endswith(('.png.import','.jpg.import')):
        text=path.read_text('utf-8').replace('mipmaps/generate=false','mipmaps/generate=true')
        text=text.replace('compress/mode=0','compress/mode=1').replace('compress/lossy_quality=0.7','compress/lossy_quality=0.88')
        path.write_text(text,encoding='utf-8')

scene=project/'scenes/hospital.tscn'
text=scene.read_text('utf-8')
for prop in ['ssr_enabled','ssao_enabled','ssil_enabled','volumetric_fog_enabled','glow_enabled']:
    text=text.replace(prop+' = true',prop+' = false')
# GPU particles are not supported by the Compatibility renderer. The web adapter
# replaces this volume with a lightweight deterministic MultiMesh dust field.
text=re.sub(r'\[node name="AirborneDust" type="GPUParticles3D".*?(?=\n\[node)', '', text, flags=re.S)
scene.write_text(text,encoding='utf-8')
(ROOT/'reports/asset_adaptations.json').write_text(json.dumps(changed,indent=2),encoding='utf-8')
print('Web textures resized:',len(changed),'; unsupported environment features removed in web copy.')
