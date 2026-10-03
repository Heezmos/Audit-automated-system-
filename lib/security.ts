/** App-owned controls; platform dispatch remains the authentication boundary. */
export async function secureAPIRequest(request: Request): Promise<Request | Response> {
 const url=new URL(request.url);
 if(!url.pathname.startsWith('/api/'))return request;
 if(!['GET','HEAD','POST'].includes(request.method))return Response.json({error:'Method not allowed.'},{status:405,headers:{Allow:'GET, HEAD, POST'}});
 if(request.method!=='POST')return request;
 const origin=request.headers.get('origin'),site=request.headers.get('sec-fetch-site');
 if(request.headers.get('x-audit-request')!=='1'||(origin&&origin!==url.origin)||(site&& !['same-origin','none'].includes(site)))return Response.json({error:'This request could not be verified. Reload the workspace and try again.'},{status:403});
 const type=request.headers.get('content-type')?.split(';')[0].trim().toLowerCase();
 if(type!=='application/json'&&type!=='multipart/form-data')return Response.json({error:'Unsupported request format.'},{status:415});
 const limit=type==='multipart/form-data'?(url.pathname==='/api/checks'?600*1024:11*1024*1024):64*1024;
 const declared=Number(request.headers.get('content-length'));
 if(Number.isFinite(declared)&&declared>limit)return Response.json({error:'Request too large.'},{status:413});
 const reader=request.body?.getReader();if(!reader)return request;
 const chunks:Uint8Array[]=[];let size=0;
 for(;;){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>limit){await reader.cancel();return Response.json({error:'Request too large.'},{status:413})}chunks.push(value)}
 const body=new Uint8Array(size);let offset=0;for(const chunk of chunks){body.set(chunk,offset);offset+=chunk.byteLength}
 return new Request(request,{body});
}
export function securityCSP(nonce?:string,development=false):string {
 const script=development?"'self' 'unsafe-inline' 'unsafe-eval'":`'self'${nonce?" 'nonce-"+nonce+"'":''}`;
 return `default-src 'self'; script-src ${script}; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'${development?' ws: wss:':''}; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'self' https://chatgpt.com https://*.chatgpt.com`;
}
export function secureResponse(response:Response,request:Request,nonce?:string,development=false):Response{
 const headers=new Headers(response.headers);
 headers.set('X-Content-Type-Options','nosniff');headers.set('Referrer-Policy','no-referrer');
 headers.set('Permissions-Policy','camera=(), microphone=(), geolocation=(), payment=(), usb=()');
 headers.set('Cross-Origin-Resource-Policy','same-origin');
 headers.set('Content-Security-Policy',securityCSP(nonce,development));
 if(new URL(request.url).protocol==='https:')headers.set('Strict-Transport-Security','max-age=31536000');
 if(!new URL(request.url).pathname.startsWith('/assets/')){headers.set('Cache-Control','private, no-store, max-age=0');headers.set('Pragma','no-cache');headers.set('Expires','0')}
 return new Response(response.body,{status:response.status,statusText:response.statusText,headers});
}
export function validateEvidence(name:string,bytes:ArrayBuffer):string|null{
 if(/[\x00-\x1f\x7f/\\]/.test(name)||!name)return 'Use a filename without control characters or path separators.';
 const ext=name.split('.').pop()?.toLowerCase();const data=new Uint8Array(bytes);const starts=(prefix:number[])=>prefix.every((b,i)=>data[i]===b);
 if(ext==='pdf'&&!starts([37,80,68,70,45]))return 'The file content does not match a PDF.';
 if(ext==='png'&&!starts([137,80,78,71,13,10,26,10]))return 'The file content does not match a PNG image.';
 if(['jpg','jpeg'].includes(ext||'')&&!starts([255,216,255]))return 'The file content does not match a JPEG image.';
 if(['xlsx','docx'].includes(ext||'')&&!starts([80,75,3,4]))return 'The file content does not match an Office document.';
 if(ext==='xls'&&!starts([208,207,17,224,161,177,26,225]))return 'Use an XLS workbook or convert it to XLSX.';
 if(['txt','csv'].includes(ext||'')){try{const text=new TextDecoder('utf-8',{fatal:true}).decode(bytes);if(text.includes('\x00'))return 'Text files must not contain binary data.'}catch{return 'Text files must use UTF-8 encoding.'}}
 return null;
}
export function csvCell(value:string):string {return '"'+(/^[\s\x00-\x1f]*[=+@-]|^[\t\r\n]/.test(value)?"'":'')+value.replaceAll('"','""')+'"'}
