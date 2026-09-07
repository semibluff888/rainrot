"""Loopback-only static server. No game installation is required by the browser."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse, mimetypes, json

ROOT = Path(__file__).resolve().parents[1] / 'site'
mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('application/octet-stream', '.pck')

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)
    def do_GET(self):
        if self.path == '/health':
            data = b'{"app":"rainrot-web"}'
            self.send_response(200); self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
            return
        super().do_GET()
    def send_head(self):
        original = Path(self.translate_path(self.path))
        packed = original.with_name(original.name+'.gz')
        if original.is_file() and packed.is_file() and 'gzip' in self.headers.get('Accept-Encoding',''):
            f=packed.open('rb')
            self.send_response(200)
            self.send_header('Content-Type', self.guess_type(str(original)))
            self.send_header('Content-Encoding','gzip')
            self.send_header('Content-Length',str(packed.stat().st_size))
            self.send_header('Vary','Accept-Encoding')
            self.send_header('Cache-Control','no-cache')
            self.end_headers()
            return f
        return super().send_head()
    def end_headers(self):
        self.send_header('X-Content-Type-Options','nosniff')
        super().end_headers()

if __name__ == '__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--port',type=int,default=9089); ap.add_argument('--directory',type=Path,default=ROOT)
    opts=ap.parse_args()
    ROOT=opts.directory.resolve()
    if not ROOT.is_dir():ap.error('Site directory does not exist')
    server=ThreadingHTTPServer(('127.0.0.1',opts.port),Handler)
    print(f'RAINROT Web: http://127.0.0.1:{opts.port}/',flush=True)
    server.serve_forever()
