"""Download pinned CC0 Poly Haven resources. Idempotent, bounded, no executables."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib, json, time, urllib.request

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'

def read(url):
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'RainrotGame/1.0 (CC0 asset download)'})
            with urllib.request.urlopen(req, timeout=80) as r:
                return r.read()
        except Exception:
            if attempt == 2: raise
            time.sleep(1 + attempt)

def download(path, info):
    path.parent.mkdir(parents=True, exist_ok=True)
    expected = info.get('md5')
    if path.exists() and (not expected or hashlib.md5(path.read_bytes()).hexdigest() == expected):
        return
    data = read(info['url'])
    if expected and hashlib.md5(data).hexdigest() != expected:
        raise ValueError('Checksum failed: ' + str(path))
    path.write_bytes(data)

def asset(asset_id, kind):
    meta = json.loads(read('https://api.polyhaven.com/files/' + asset_id))
    dest = ASSETS / kind / asset_id
    files = []
    if kind == 'textures':
        for channel, short in [('Diffuse','diff'),('nor_gl','normal'),('Rough','rough')]:
            formats = meta[channel]['1k']
            ext = 'jpg' if 'jpg' in formats else 'png'
            info = formats[ext]
            download(dest / (short + '.' + ext), info)
            files.append({'path': str((dest/(short+'.'+ext)).relative_to(ROOT)), **info})
    else:
        info = meta['gltf']['1k']['gltf']
        download(dest / (asset_id + '.gltf'), info)
        files.append({'path': str((dest/(asset_id+'.gltf')).relative_to(ROOT)), 'url': info['url'], 'md5': info.get('md5')})
        for name, dep in info['include'].items():
            target = (dest / name).resolve()
            try: target.relative_to(dest.resolve())
            except ValueError: raise ValueError('Unsafe asset path')
            download(target, dep)
            files.append({'path': str(target.relative_to(ROOT)), **dep})
    print('OK', asset_id, flush=True)
    return {'id':asset_id,'source':'https://polyhaven.com/a/'+asset_id,'license':'CC0-1.0','files':files}

def main():
    jobs = [(s,'textures') for s in ['blue_plaster_weathered','concrete_floor_worn_001','rusty_metal_sheet','brown_floor_tiles','damaged_plaster','dark_wood']]
    jobs += [(s,'models') for s in ['wheelchair_01','old_bed_frame','portable_cassette_player','desk_lamp_arm_01','portable_generator']]
    results, failures = [], []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(asset,*j):j for j in jobs}
        for f in as_completed(futures):
            try: results.append(f.result())
            except Exception as e:
                failures.append([futures[f],str(e)])
                print('FAILED',futures[f],str(e),flush=True)
    (ASSETS/'manifest.json').write_text(json.dumps({'assets':results,'failures':failures},ensure_ascii=False,indent=2),encoding='utf-8')
    font = ASSETS/'fonts'/'NotoSansSC.ttf'
    download(font, {'url':'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf'})
    download(ASSETS/'fonts'/'OFL.txt', {'url':'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt'})
    print('Font ready; assets:',len(results),'failures:',len(failures),flush=True)
    if failures: raise SystemExit(1)

if __name__ == '__main__': main()
