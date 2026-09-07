"""Package the editable offline project, original source assets and validation."""
from pathlib import Path
import zipfile
import hashlib

root=Path(__file__).resolve().parents[1]
output=root/'delivery/RAINROT_Monsters_2026-09-07.zip'
output.parent.mkdir(exist_ok=True)
excluded={'.runtime','.godot','.git','.codex','.agents','delivery','__pycache__'}
logs={'integration_monsters.log','enemy_test.log','walkthrough_monsters.log','walkthrough_zero_ammo.log',
      'benchmark_monsters.log','enemy_movie_final.log','build_enemy_visuals.log','level_monsters.log'}
reports={'test_report.json','enemy_test_report.json','walkthrough.json','walkthrough_zero_ammo.json',
         'benchmark.json','RAINROT_Enemy_Demo.mp4','demo_contact_sheet.jpg'}
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=5) as archive:
    for path in sorted(root.rglob('*')):
        if not path.is_file():continue
        rel=path.relative_to(root)
        if any(part in excluded for part in rel.parts):continue
        if rel.parts[0]=='logs' and path.name not in logs:continue
        if rel.parts[0]=='captures':
            if path.name not in reports and not (path.suffix=='.png' and path.name[:2].isdigit() and path.name[:2]!='08') and not path.name.startswith('benchmark_'):continue
            if path.suffix=='.import':continue
        archive.write(path,Path('RAINROT')/rel)
    for role in ['smily','nurse']:
        for suffix in ['glb','zip']:
            source=root/'.runtime/monster_sources'/f'{role}.{suffix}'
            if not source.exists():source=root/'source_archives'/f'{role}.{suffix}'
            archive.write(source,f'RAINROT/source_archives/{role}.{suffix}')
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    for required in ['project.godot','Launch.cmd','scenes/hospital.tscn','scenes/enemies/smily_visual.tscn',
                     'scenes/enemies/nurse_visual.tscn','scenes/enemies/nurse_elite_visual.tscn','captures/RAINROT_Enemy_Demo.mp4']:
        assert 'RAINROT/'+required in archive.namelist(),required
    print('Archive verified:',len(archive.namelist()),'files;',round(output.stat().st_size/1024/1024,1),'MiB')
digest=hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix('.zip.sha256').write_text(digest+'  '+output.name+'\n',encoding='ascii')
print(output)
print('SHA256',digest)
