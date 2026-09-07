"""Fetch the pinned official Windows x64 release template using ZIP range reads."""
import io,json,hashlib,urllib.request,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/'.runtime/windows-toolchain'
ROOT.mkdir(parents=True,exist_ok=True)
URL='https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz'
SIZE=1280486955

class RemoteZip(io.RawIOBase):
    def __init__(self):self.pos=0;self.cache={};self.downloaded=0
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.pos
    def seek(self,offset,whence=0):
        self.pos=offset if whence==0 else self.pos+offset if whence==1 else SIZE+offset
        return self.pos
    def read(self,size=-1):
        if size<0:size=SIZE-self.pos
        size=min(size,SIZE-self.pos)
        if size<=0:return b''
        start=self.pos;end=start+size-1
        for (a,b),data in self.cache.items():
            if a<=start and end<=b:self.pos+=size;return data[start-a:end-a+1]
        # Combine ZIP's small adjacent header reads into one request.
        fetch_start=max(0,start-1024) if size<65536 else start
        fetch_end=min(SIZE-1,max(end,fetch_start+65535))
        req=urllib.request.Request(URL,headers={'User-Agent':'RAINROT-web-port','Range':f'bytes={fetch_start}-{fetch_end}'})
        with urllib.request.urlopen(req,timeout=120) as response:
            if response.status!=206:
                raise RuntimeError('Server did not honor a range request; refusing a full 1.28 GB fetch.')
            data=response.read()
        assert len(data)==fetch_end-fetch_start+1,(len(data),fetch_start,fetch_end)
        self.downloaded+=len(data)
        self.cache[(fetch_start,fetch_end)]=data
        self.pos+=size
        return data[start-fetch_start:end-fetch_start+1]


if __name__ == '__main__':
    import sys
    manifest_path = Path(__file__).with_name('windows-templates.json')
    record = '--record' in sys.argv
    expected = {} if record else json.loads(manifest_path.read_text(encoding='utf-8'))
    names = ['windows_release_x86_64.exe', 'windows_release_x86_64_console.exe']
    remote = RemoteZip()
    result = {}
    with zipfile.ZipFile(remote) as archive:
        for name in names:
            target = ROOT / name
            if target.exists() and name in expected and hashlib.sha256(target.read_bytes()).hexdigest() == expected[name]:
                print('VERIFIED', name, flush=True)
                continue
            data = archive.read('templates/' + name)
            digest = hashlib.sha256(data).hexdigest()
            if not record and digest != expected.get(name):
                raise RuntimeError('Template checksum mismatch: ' + name)
            target.write_bytes(data)
            result[name] = digest
            print('SAVED', name, len(data), flush=True)
    if record:
        manifest_path.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    for name in ['LICENSE.txt', 'COPYRIGHT.txt']:
        url = 'https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/' + name
        with urllib.request.urlopen(url, timeout=60) as response:
            (ROOT / ('GODOT_' + name)).write_bytes(response.read())
