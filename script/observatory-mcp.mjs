#!/usr/bin/env node
// Local stdio MCP bridge. Credentials stay outside the dotfiles repository.
import {createServer} from 'node:http';
import {generateKeyPairSync,randomBytes,privateDecrypt,constants,createDecipheriv} from 'node:crypto';
import {readFile,mkdir,writeFile,rename,unlink,chmod} from 'node:fs/promises';
import {homedir} from 'node:os';
import {join,dirname} from 'node:path';
import {createInterface} from 'node:readline';
import {spawn} from 'node:child_process';
import {pathToFileURL} from 'node:url';

export const ORIGIN='https://agent-observatory-hub.peachy-pony-3346.chatgpt.site';
export const credentialsPath=()=>join(process.env.XDG_CONFIG_HOME||join(homedir(),'.config'),'observatory','credentials.json');
export function unseal(packet,privateKey,state){
  if(packet?.v!==1)throw Error('Unsupported pairing format');
  const key=privateDecrypt({key:privateKey,padding:constants.RSA_PKCS1_OAEP_PADDING,oaepHash:'sha256'},Buffer.from(packet.key,'base64'));
  const encrypted=Buffer.from(packet.data,'base64');
  const decrypt=createDecipheriv('aes-256-gcm',key,Buffer.from(packet.iv,'base64'));
  decrypt.setAuthTag(encrypted.subarray(-16));
  const value=JSON.parse(Buffer.concat([decrypt.update(encrypted.subarray(0,-16)),decrypt.final()]).toString('utf8'));
  if(value.state!==state||value.origin!==ORIGIN||!/^obs_[a-f0-9]{64}$/.test(value.token)||typeof value.serviceToken!=='string'||!value.serviceToken||!Number.isFinite(Date.parse(value.expires))||Date.parse(value.expires)<=Date.now())throw Error('Invalid or expired pairing response');
  delete value.state;
  return value;
}
export async function saveCredentials(value){
  const path=credentialsPath();await mkdir(dirname(path),{recursive:true,mode:0o700});
  const temporary=path+'.'+randomBytes(8).toString('hex')+'.tmp';
  try{await writeFile(temporary,JSON.stringify(value),{mode:0o600,flag:'wx'});await rename(temporary,path);await chmod(path,0o600)}finally{await unlink(temporary).catch(()=>{})}
}
export async function loadCredentials(){
  let value;try{value=JSON.parse(await readFile(credentialsPath(),'utf8'))}catch{throw Error('Not connected. Run observatory connect first.')}
  if(value.origin!==ORIGIN||!/^obs_[a-f0-9]{64}$/.test(value.token)||typeof value.serviceToken!=='string'||!value.serviceToken)throw Error('Invalid credentials. Run observatory connect again.');
  if(!Number.isFinite(Date.parse(value.expires))||Date.parse(value.expires)<=Date.now())throw Error('Connection expired. Run observatory connect again.');
  return value;
}
export async function remote(request,credential,fetcher=fetch){
  if(credential.origin!==ORIGIN)throw Error('Unexpected destination; request refused.');
  const response=await fetcher(ORIGIN+'/api/agent-mcp',{method:'POST',redirect:'error',signal:AbortSignal.timeout(30000),headers:{'Content-Type':'application/json','X-Observatory-Agent-Token':credential.token,'OAI-Sites-Authorization':'Bearer '+credential.serviceToken},body:JSON.stringify(request)});
  if(!response.ok)throw Error(response.status===401||response.status===403?'Agent access rejected or expired. Run observatory connect again.':'Agent server failed ('+response.status+').');
  if(response.status===202)return null;
  if(!response.headers.get('content-type')?.includes('application/json'))throw Error('Server returned non-JSON content. Reconnect with observatory connect.');
  return response.json();
}
export async function serve(){
  const lines=createInterface({input:process.stdin,crlfDelay:Infinity});
  for await(const line of lines){
    if(!line.trim())continue;
    let request;
    try{if(line.length>65536)throw Error();request=JSON.parse(line)}catch{process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:null,error:{code:-32700,message:'Invalid JSON request'}})+'\n');continue}
    if(request?.id===undefined)continue;
    try{const response=await remote(request,await loadCredentials());if(response)process.stdout.write(JSON.stringify(response)+'\n')}
    catch(error){process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:request.id,error:{code:-32001,message:error.message||'Agent connection failed'}})+'\n')}
  }
}
export async function connect(label='Local agents'){
  const {publicKey,privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});
  const state=randomBytes(32).toString('hex');
  let resolveDone,rejectDone;
  const done=new Promise((resolve,reject)=>{resolveDone=resolve;rejectDone=reject});
  const server=createServer(async(request,response)=>{
    try{
      const expected='127.0.0.1:'+server.address().port;
      if(request.headers.host!==expected||request.method!=='GET'){response.writeHead(403).end('Forbidden');return}
      const url=new URL(request.url,'http://'+expected);
      if(url.pathname!=='/callback'||url.searchParams.get('state')!==state){response.writeHead(400).end('Invalid connection callback');return}
      const raw=url.searchParams.get('sealed')||'';if(raw.length>16000)throw Error();
      const credential=unseal(JSON.parse(raw),privateKey,state);
      await saveCredentials(credential);
      response.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'"}).end('<!doctype html><title>Observatory connected</title><body style="background:#0f1418;color:#dce5e1;font-family:system-ui;padding:48px"><h1>Connected.</h1><p>You can close this tab and return to your terminal.</p></body>');
      resolveDone();
    }catch{response.writeHead(400).end('Connection could not be verified. Retry from the terminal.')}
  });
  const timer=setTimeout(()=>rejectDone(Error('Pairing timed out. Run observatory connect again.')),10*60*1000);
  try{
    await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve)});
    const callback='http://127.0.0.1:'+server.address().port+'/callback';
    const params=new URLSearchParams({key:publicKey.export({type:'spki',format:'der'}).toString('base64'),state,callback,label:label.slice(0,80)});
    const url=ORIGIN+'/connect#'+params;
    console.error('Open this URL on this computer and approve the connection:\n'+url+'\nWaiting for approval...');
    const program=process.platform==='darwin'?'open':process.platform==='win32'?null:'xdg-open';
    if(program){const child=spawn(program,[url],{stdio:'ignore'});child.on('error',()=>{});child.unref()}
    await done;
    console.error('Connected. Credentials saved privately. Run observatory setup, then restart your agent.');
  }finally{clearTimeout(timer);server.close();server.closeIdleConnections()}
}
async function disconnect(){
  const credential=await loadCredentials();
  const response=await fetch(ORIGIN+'/api/agent-mcp',{method:'DELETE',redirect:'error',signal:AbortSignal.timeout(30000),headers:{'X-Observatory-Agent-Token':credential.token,'OAI-Sites-Authorization':'Bearer '+credential.serviceToken}});
  if(!response.ok&&response.status!==401)throw Error('Could not revoke connection; credentials retained.');
  await unlink(credentialsPath());console.error('Connection revoked. Local credentials removed.');
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  const command=process.argv[2]||'serve';
  try{if(command==='serve')await serve();else if(command==='connect')await connect(process.argv.slice(3).join(' ')||'Local agents');else if(command==='disconnect')await disconnect();else throw Error('Usage: observatory-mcp [serve|connect [label]|disconnect]')}
  catch(error){console.error(error.message||'Connection failed.');process.exitCode=1}
}
