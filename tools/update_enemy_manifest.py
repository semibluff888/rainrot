"""Update attribution and verify the delivered monster files, without network access."""
import hashlib
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1]
manifest_path=root/'assets/manifest.json'
manifest=json.loads(manifest_path.read_text('utf-8'))
manifest['assets']=[a for a in manifest['assets'] if a['id'] not in ['smily','nurse']]
for role in ['smily','nurse']:
    folder=root/'assets/models/enemies'/role
    source=json.loads((folder/'SOURCE.json').read_text('utf-8'))
    source['changes']='Original geometry and UVs preserved. External glTF textures; 2K/1K tiers; base-color saturation 86%; Godot PBR roughness/metallic/alpha-scissor tuning; floor pivot and facing normalization; editable in-place skeletal animation clips; bone hitboxes.'
    if role=='nurse':
        source['changes']+=' Added twelve joints and blended weights for six lower appendages; attached original needle meshes to the matching hand bones; separate elite stance and timing.'
    else:
        source['changes']+=' Preserved source ArmatureAction in glTF; created game idle, alert, dragging walk, burst, attack, stun and death clips; static containment specimen.'
    (folder/'SOURCE.json').write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
    files=[]
    for path in sorted(folder.rglob('*')):
        if path.is_file() and path.suffix not in ['.import','.uid']:
            data=path.read_bytes()
            files.append({'path':path.relative_to(root).as_posix(),'sha256':hashlib.sha256(data).hexdigest(),'size':len(data)})
    manifest['assets'].append({'id':role,'title':source['title'],'author':source['author'],'source':source['source'],
                               'license':source['license'],'license_url':source['license_url'],'download_date':source['date'],
                               'sha256_source_glb':source['sha256_source_glb'],'sha256_source_archive':source['sha256_source_archive'],
                               'changes':source['changes'],'files':files})
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
checked=0
for asset in manifest['assets']:
    for entry in asset.get('files',[]):
        path=root/entry['path']
        data=path.read_bytes()
        algorithm='sha256' if 'sha256' in entry else 'md5'
        assert hashlib.new(algorithm,data).hexdigest()==entry[algorithm], str(path)
        checked+=1
print('Verified',len(manifest['assets']),'asset groups;',checked,'files; MD5/SHA256 match.')
