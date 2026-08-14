#!/usr/bin/env python3
"""Local image drop page for the image-vision-bridge skill.

Why: some chat UIs (e.g. DeepSeek Harness with a text-only model) reject image
attachments at the model level. This tiny server gives you a browser page where
you can paste (Cmd/Ctrl+V) or drag images; each one is saved to disk and listed
with its path, which the agent then feeds into the OCR / vision pipeline.

Usage:  python3 upload-server.py [port] [outdir]
Example: python3 upload-server.py 8765 /tmp/vision-uploads
Then open http://127.0.0.1:8765/ and paste/drag images.
"""
import http.server
import json
import os
import socketserver
import sys
import time
import urllib.parse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
OUTDIR = sys.argv[2] if len(sys.argv) > 2 else "/tmp/vision-uploads"
os.makedirs(OUTDIR, exist_ok=True)

PAGE = """<!doctype html>
<html lang="zh"><head><meta charset="utf-8"><title>Vision Upload</title>
<style>
body{font-family:-apple-system,sans-serif;max-width:640px;margin:40px auto;padding:0 16px;color:#222}
#drop{border:2px dashed #888;border-radius:12px;padding:48px 16px;text-align:center;font-size:18px;color:#555;cursor:pointer}
#drop.drag{border-color:#4a90d9;background:#eef4fd}
ul{list-style:none;padding:0}li{padding:6px 0;border-bottom:1px solid #eee;font-size:13px;word-break:break-all}
code{background:#f4f4f4;padding:2px 6px;border-radius:4px}
</style></head><body>
<h2>粘贴 / 拖入图片</h2>
<p>按 <code>Cmd+V</code> 粘贴剪贴板图片，或把图片文件拖到下方区域。保存后把路径告诉 Agent 即可。</p>
<div id="drop">在此粘贴 (Cmd+V) 或拖入图片</div>
<h3>已上传</h3><ul id="list"></ul>
<script>
const drop=document.getElementById('drop'),list=document.getElementById('list');
async function send(blob,name){
  const buf=await blob.arrayBuffer();
  const b64=btoa(String.fromCharCode(...new Uint8Array(buf)));
  const r=await fetch('/upload',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({name,image:'data:'+(blob.type||'image/png')+';base64,'+b64})});
  const j=await r.json();
  const li=document.createElement('li');
  li.innerHTML='<code>'+j.path+'</code> ('+name+')';
  list.prepend(li);
}
['paste','drop'].forEach(ev=>document.addEventListener(ev,e=>{
  e.preventDefault();
  const items=ev.clipboardData?ev.clipboardData.items:(ev.dataTransfer?ev.dataTransfer.files:[]);
  for(const it of items){
    const f=it.getAsFile?it.getAsFile():it;
    if(f&&f.type.startsWith('image/')) send(f,f.name||('clipboard-'+Date.now()+'.png'));
  }
}));
</script></body></html>"""

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/":
            self.send_error(404); return
        body = PAGE.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/upload":
            self.send_error(404); return
        try:
            n = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(n))
            raw = data["image"].split(";base64,")[1]
            import base64
            blob = base64.b64decode(raw)
            fn = "upload-%d.png" % int(time.time() * 1000)
            path = os.path.join(OUTDIR, fn)
            with open(path, "wb") as f:
                f.write(blob)
            resp = json.dumps({"ok": True, "path": path}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
        except Exception as e:
            resp = json.dumps({"ok": False, "error": str(e)}).encode()
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

    def log_message(self, *a):
        pass

if __name__ == "__main__":
    print("Vision upload server: http://127.0.0.1:%d/  ->  %s" % (PORT, OUTDIR))
    with socketserver.ThreadingTCPServer(("127.0.0.1", PORT), H) as srv:
        srv.serve_forever()
