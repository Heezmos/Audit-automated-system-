"""Private ClamAV adapter. Put behind HTTPS; never log evidence or bearer tokens."""
import hashlib,hmac,json,os,socket,struct
from datetime import datetime,timezone
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
TOKEN=os.environ.get('AUDIT_SCANNER_TOKEN','')
if len(TOKEN)<32:raise RuntimeError('Provide a private scanner token of at least 32 characters')
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def respond(self,code,value):
  data=json.dumps(value).encode();self.send_response(code);self.send_header('Content-Type','application/json');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def do_POST(self):
  if self.path!='/scan' or not hmac.compare_digest(self.headers.get('Authorization',''),'Bearer '+TOKEN):return self.respond(403,{'error':'Access denied'})
  try:
   size=int(self.headers.get('Content-Length','0'))
   if size<1 or size>10*1024*1024 or self.headers.get('Transfer-Encoding'):return self.respond(413,{'error':'Unsupported upload size'})
   self.connection.settimeout(30);data=self.rfile.read(size)
   if len(data)!=size:return self.respond(400,{'error':'Incomplete upload'})
   digest=hashlib.sha256(data).hexdigest()
   if not hmac.compare_digest(digest,self.headers.get('X-Evidence-SHA256','')):return self.respond(400,{'error':'Hash mismatch'})
   def connect():
    s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);s.settimeout(40);s.connect('/run/clamav/clamd.ctl');return s
   with connect() as s:
    s.sendall(b'zINSTREAM\0')
    for start in range(0,len(data),65536):
     chunk=data[start:start+65536];s.sendall(struct.pack('!I',len(chunk))+chunk)
    s.sendall(struct.pack('!I',0));result=s.recv(4096).decode().strip('\0\n')
   if result.endswith(' OK'):verdict='clean'
   elif result.endswith(' FOUND'):verdict='infected'
   else:raise RuntimeError('Scan incomplete')
   with connect() as s:s.sendall(b'zVERSION\0');version=s.recv(4096).decode().strip('\0\n')
   daily=[os.path.join('/var/lib/clamav',n) for n in ('daily.cvd','daily.cld') if os.path.exists(os.path.join('/var/lib/clamav',n))]
   if not daily:raise RuntimeError('Signatures unavailable')
   updated=datetime.fromtimestamp(max(os.path.getmtime(p) for p in daily),timezone.utc).isoformat()
   return self.respond(200,{'verdict':verdict,'sha256':digest,'engine':'ClamAV','version':version,'signaturesUpdatedAt':updated})
  except Exception:return self.respond(503,{'error':'Scan failed; quarantine must remain'})
ThreadingHTTPServer(('0.0.0.0',8080),Handler).serve_forever()
