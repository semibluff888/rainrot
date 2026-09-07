"""Fetch only the official Godot web templates using HTTP ZIP range reads."""
import io,json,hashlib,urllib.request,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
(ROOT/'toolchain').mkdir(parents=True,exist_ok=True)
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

remote=RemoteZip()
report={'engine':'4.7.1.stable','source':URL,'templates':[]}
with zipfile.ZipFile(remote) as archive:
    web=[n for n in archive.namelist() if 'web_' in n and n.endswith('.zip')]
    print('OFFICIAL_WEB_TEMPLATES',web,flush=True)
    for name in web:
        # Prefer single-threaded web builds: deployable on ordinary static hosting.
        if 'nothreads' not in name or 'dlink' in name:continue
        data=archive.read(name)
        target=ROOT/'toolchain'/Path(name).name
        target.write_bytes(data)
        report['templates'].append({'file':target.name,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        print('SAVED',target.name,len(data),flush=True)
report['downloaded_bytes']=remote.downloaded
(ROOT/'toolchain/SOURCE.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('DOWNLOADED_MIB',round(remote.downloaded/1024/1024,1),flush=True)
