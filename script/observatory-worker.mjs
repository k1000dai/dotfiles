#!/usr/bin/env node
// Resident worker: one job at a time; no listening ports, shell interpolation or uploaded transcripts.
import {hostname,platform,arch,cpus,totalmem,loadavg,homedir} from 'node:os';
import {readFile,mkdir,writeFile,open,unlink,realpath,readdir,copyFile,rm,stat} from 'node:fs/promises';
import {constants} from 'node:fs';
import {join,dirname,resolve,basename,sep} from 'node:path';
import {spawn,execFile,execFileSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {promisify} from 'node:util';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {ORIGIN,loadCredentials} from './observatory-mcp.mjs';
export const configDir=()=>join(process.env.XDG_CONFIG_HOME||join(homedir(),'.config'),'observatory');
export const stateDir=()=>join(process.env.XDG_STATE_HOME||join(homedir(),'.local','state'),'observatory');
const configPath=()=>join(configDir(),'worker.json');
const safeId=id=>typeof id==='string'&&/^[a-f0-9-]{36}$/.test(id);
const ownerPattern=/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/,repoPattern=/^([A-Za-z0-9][A-Za-z0-9-]{0,38})\/([A-Za-z0-9_.-]{1,100})$/;
const ownerAllowed=(config,owner)=>(config.owners||[]).some(o=>o.toLowerCase()===owner.toLowerCase());
// Reason Network carries replies and files between agents; Observatory keeps the queue, cancellation and results.
// `work` is a reserved pseudo-repository: the job runs in ~/work/<job-id>, seeded with files sent over Reason Network.
export const WORKSPACE_REPO='work',REASON_SESSION='observatory-worker';
export const workspaceDir=id=>join(homedir(),'work',id);
const reasonInbox=()=>join(process.env.REASON_NETWORK_HOME||join(homedir(),'.reason','network'),'inbox');
const reasonPart=/^[A-Za-z0-9][^\s/*:@"<>]{0,99}$/,filesTag=/^[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$/;
export function validateConfig(c){
 if(!c||!safeId(c.deviceId)||typeof c.repos!=='object'||!c.repos||Array.isArray(c.repos)||Object.entries(c.repos).some(([alias,path])=>!/^[-a-zA-Z0-9_]{1,80}$/.test(alias)||alias===WORKSPACE_REPO||typeof path!=='string'||!path.startsWith('/'))||Object.keys(c.repos).length>30)throw Error('Invalid worker configuration');
 if(!Array.isArray(c.agents)||c.agents.some(a=>!['codex','claude'].includes(a)))throw Error('Invalid agents');
 if(c.owners!==undefined&&(!Array.isArray(c.owners)||c.owners.length>20||c.owners.some(o=>typeof o!=='string'||!ownerPattern.test(o))))throw Error('Invalid owners');
 return c;
}
const execAsync=promisify(execFile);
// GIT_TERMINAL_PROMPT=0 keeps an unattended clone/fetch from waiting on credentials.
export const execText=(cmd,args,timeout)=>execAsync(cmd,args,{encoding:'utf8',timeout,maxBuffer:4*1024*1024,env:{...process.env,GIT_TERMINAL_PROMPT:'0'}}).then(r=>r.stdout.trim());
// GitHub repositories under allowed owners: ghq clones plus gh-visible ones that can be cloned on demand.
export async function availableRepos(config,exec=execText){
 const found=new Map(),add=name=>{const m=repoPattern.exec(name);if(m&&!/^\.+$/.test(m[2])&&ownerAllowed(config,m[1])&&!found.has(name.toLowerCase()))found.set(name.toLowerCase(),name)};
 if(config.owners?.length){
  try{for(const line of (await exec('ghq',['list'],30000)).split('\n')){const [host,...rest]=line.split('/');if(host==='github.com')add(rest.join('/'))}}catch{}
  for(const owner of config.owners)try{(await exec('gh',['repo','list',owner,'--limit','1000','--no-archived','--json','nameWithOwner','--jq','.[].nameWithOwner'],30000)).split('\n').forEach(add)}catch{}
 }
 return [...Object.keys(config.repos),...[...found.values()].sort()];
}
export async function resolveRepo(config,name,exec=execText){
 if(Object.hasOwn(config.repos,name))return {path:config.repos[name],ghq:false};
 const m=repoPattern.exec(name);if(!m||/^\.+$/.test(m[2])||!ownerAllowed(config,m[1]))throw Error('Job rejected by local policy');
 const url='github.com/'+name,find=async()=>(await exec('ghq',['list','-p','-e',url],30000)).split('\n')[0];
 let path=await find();if(!path){await exec('ghq',['get',url],600000);path=await find()}
 if(!path)throw Error('Repository could not be cloned');
 return {path,ghq:true};
}
// Prompt lines `Observatory-Reply-To: person/session[@machine]` and `Observatory-Files: <tag>`; groups are never accepted.
export function jobDirectives(prompt){
 const field=name=>new RegExp('^'+name+':[ \\t]*(\\S+)[ \\t]*$','im').exec(prompt)?.[1];
 const replyTo=field('Observatory-Reply-To'),files=field('Observatory-Files'),[person,session,...extra]=(replyTo||'').split('/'),[name,machine,...more]=(session||'').split('@');
 const address=replyTo&&!extra.length&&!more.length&&reasonPart.test(person)&&reasonPart.test(name)&&(machine===undefined||reasonPart.test(machine));
 return {replyTo:address?replyTo:undefined,files:files&&filesTag.test(files)?files:undefined};
}
// `reason-network listen` frames: a body cannot open or close a frame, and saved files are listed after it.
export function parseListen(text,inbox=reasonInbox()){
 const unescape=s=>s.replaceAll('&quot;','"').replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&amp;','&'),messages=[];
 for(const [,attrs,body,files] of text.matchAll(/^<reason-message ([^\n]*)>\n([\s\S]*?)\n<\/reason-message>\n((?:Files they sent with [^\n]*\n(?:- [^\n]*\n)*)?)/gm)){
  const attr=name=>{const m=new RegExp('(?:^| )'+name+'="([^"]*)"').exec(attrs);return m?unescape(m[1]):undefined};
  messages.push({id:attr('id'),from:attr('from'),body,files:files.split('\n').filter(l=>l.startsWith('- ')).map(l=>l.slice(2)).filter(p=>p.startsWith(inbox+sep))});
 }
 return messages;
}
export async function reasonIdentity(exec=execText){
 try{const team=JSON.parse(await exec('reason-network',['team','--json'],30000));return typeof team.person==='string'&&typeof team.machine==='string'?{person:team.person,machine:team.machine}:null}catch{return null}
}
// Reading the worker's mailbox also keeps its session live. Only this person's own sessions may stage job files.
export async function collectFiles(identity,exec=execText,wait=0){
 const text=await exec('reason-network',['listen','--as',REASON_SESSION,'--wait',String(wait)],(wait+30)*1000);let stored=0;
 for(const m of parseListen(text)){
  const tag=/^observatory-files:?[ \t]+(\S+)[ \t]*$/im.exec(m.body)?.[1];
  if(!tag||!filesTag.test(tag)||!m.from?.startsWith(identity.person+'/')||!m.files.length)continue;
  const dir=join(stateDir(),'files',tag),inbox=await realpath(reasonInbox());await rm(dir,{recursive:true,force:true});await mkdir(dir,{recursive:true,mode:0o700});
  for(const file of m.files){const real=await realpath(file).catch(()=>'');if(real.startsWith(inbox+sep))await copyFile(real,join(dir,basename(real)))}
  stored++;
 }
 return stored;
}
async function stagedFiles(tag,identity,exec,deadline,stop){
 const dir=join(stateDir(),'files',tag);
 for(;;){
  try{const names=await readdir(dir);if(names.length)return {dir,names}}catch(e){if(e.code!=='ENOENT')throw e}
  if(!identity||stop()||Date.now()>=deadline)throw Error('Files '+tag+' did not arrive over Reason Network');
  await collectFiles(identity,exec,Math.max(1,Math.min(15,Math.ceil((deadline-Date.now())/1000))));
 }
}
async function placeFiles(staged,target){await mkdir(target,{recursive:true,mode:0o700});for(const name of staged.names)await copyFile(join(staged.dir,name),join(target,name),constants.COPYFILE_EXCL);await rm(staged.dir,{recursive:true,force:true})}
// A Git baseline lets Codex run outside a repository and shows what the agent changed.
async function prepareWorkspace(job,staged,exec){
 const dir=workspaceDir(job.id);await mkdir(dirname(dir),{recursive:true});await mkdir(dir,{mode:0o700});if(staged)await placeFiles(staged,dir);
 await exec('git',['-C',dir,'init','-q'],30000);await exec('git',['-C',dir,'add','-A'],30000);
 await exec('git',['-C',dir,'-c','user.name=Observatory worker','-c','user.email=observatory-worker@localhost','-c','commit.gpgsign=false','commit','-q','--no-verify','--allow-empty','-m','Observatory job input'],30000);
 return dir;
}
// Text files the agent created or changed, within Reason Network's limits (10 files, 256 KB each, 512 KB in all).
export async function changedFiles(dir,exec=execText){
 const names=[...new Set((await exec('git',['-C',dir,'ls-files','-z','--modified','--others','--exclude-standard'],30000)).split('\0').filter(Boolean))],picked=[];let total=0;
 for(const name of names){
  if(picked.length>=10||name.split('/').some(part=>part.startsWith('.')))continue;
  const path=join(dir,name),info=await stat(path).catch(()=>null);if(!info?.isFile()||info.size>262144||total+info.size>524288)continue;
  try{if(/[\0-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(new TextDecoder('utf-8',{fatal:true}).decode(await readFile(path))))continue}catch{continue}
  picked.push(path);total+=info.size;
 }
 return picked;
}
export async function replyResult(job,outcome,identity,exec=execText){
 const {replyTo}=jobDirectives(job.prompt);if(!replyTo||!identity)return false;
 const files=outcome.workspace?await changedFiles(outcome.worktree,exec).catch(()=>[]):[],answer=outcome.answer?.trim()||'',message='Observatory job '+job.id+' '+outcome.status+': '+outcome.result+(answer?'\n\n'+(answer.length>8000?answer.slice(0,8000)+'\n[truncated]':answer):'');
 await collectFiles(identity,exec).catch(()=>{});
 const send=(attached,text)=>exec('reason-network',['send',replyTo,'--from','cli:'+REASON_SESSION,...attached.flatMap(f=>['--file',f]),'--',text],60000);
 try{await send(files,message)}catch(e){if(!files.length)throw e;await send([],message+' Changed files could not be attached; they stay in the workspace.')}
 return true;
}
async function saveConfig(c){await mkdir(configDir(),{recursive:true,mode:0o700});await writeFile(configPath(),JSON.stringify(c,null,2)+'\n',{mode:0o600})}
async function getConfig(){try{return validateConfig(JSON.parse(await readFile(configPath(),'utf8')))}catch{throw Error('Run observatory worker init first; inspect worker.json locally if it exists.')}}
export function collectSpecs(run=(cmd,args)=>execFileSync(cmd,args,{encoding:'utf8',timeout:5000,stdio:['ignore','pipe','ignore'],maxBuffer:128*1024})){
 const cpu=cpus();let gpus=[];
 try{gpus=run('nvidia-smi',['--query-gpu=name,memory.total','--format=csv,noheader,nounits']).trim().split('\n').filter(Boolean).slice(0,16).map(line=>{const [model,memory]=line.split(',');return {model:model.trim(),vramBytes:Number.isFinite(Number(memory))?Number(memory)*1048576:null}})}catch{}
 if(!gpus.length&&platform()==='darwin'){try{const data=JSON.parse(run('system_profiler',['SPDisplaysDataType','-json']));gpus=(data.SPDisplaysDataType||[]).slice(0,16).map(g=>({model:String(g.sppci_model||g._name||'Apple GPU').slice(0,200),vramBytes:null}))}catch{}}
 if(!gpus.length&&platform()==='linux'){try{gpus=run('lspci',[]).split('\n').filter(x=>/VGA compatible controller|3D controller|Display controller/i.test(x)).slice(0,16).map(x=>({model:x.split(': ').slice(1).join(': ').slice(0,200),vramBytes:null}))}catch{}}
 return {os:platform(),arch:arch(),cpu:cpu[0]?.model||'Unknown CPU',cores:cpu.length||1,memoryBytes:totalmem(),gpus,load1:loadavg()[0]??null};
}
export async function workerRequest(body,credential,fetcher=fetch){
 if(credential.origin!==ORIGIN)throw Error('Unexpected worker destination');
 const r=await fetcher(ORIGIN+'/api/worker',{method:'POST',redirect:'error',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json','X-Observatory-Agent-Token':credential.token,'OAI-Sites-Authorization':'Bearer '+credential.serviceToken},body:JSON.stringify(body)});
 if(!r.ok)throw Error('Worker request rejected ('+r.status+'); check connection and worker session.');
 if(!r.headers.get('content-type')?.includes('application/json'))throw Error('Worker server returned non-JSON');return r.json();
}
function git(repo,args){return execFileSync('git',['-C',repo,...args],{encoding:'utf8',timeout:30000,stdio:['ignore','pipe','ignore']}).trim()}
export function agentCommand(agent){
 if(agent==='codex')return ['codex',['-a','never','exec','--sandbox','workspace-write','--json','--ignore-user-config','-c','mcp_servers.observatory.enabled=false','-']];
 // MCP disabled so a remotely dispatched task cannot recursively submit work. No Bash tool or bypass permissions.
 if(agent==='claude')return ['claude',['-p','--restricted','--permission-mode','acceptEdits','--max-budget-usd','5','--tools','Read,Edit,Write,Glob,Grep','--strict-mcp-config','--mcp-config','{"mcpServers":{}}','--output-format','json']];
 throw Error('Unsupported agent');
}
export function childEnvironment(env=process.env){const clean={};for(const key of ['HOME','USER','LOGNAME','PATH','SHELL','LANG','LC_ALL','TERM','TMPDIR','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','CODEX_HOME','CLAUDE_CONFIG_DIR','SSL_CERT_FILE','SSL_CERT_DIR','HTTPS_PROXY','HTTP_PROXY','NO_PROXY','ANTHROPIC_API_KEY','OPENAI_API_KEY','CLAUDE_CODE_OAUTH_TOKEN'])if(env[key])clean[key]=env[key];clean.OBSERVATORY_WORKER_JOB='1';return clean}
export async function acquireLock(path){await mkdir(dirname(path),{recursive:true,mode:0o700});try{const h=await open(path,'wx',0o600);await h.writeFile(String(process.pid));await h.close();return async()=>unlink(path).catch(()=>{})}catch(e){if(e.code!=='EEXIST')throw e;let pid;try{pid=Number(await readFile(path,'utf8'));if(!Number.isInteger(pid)||pid<1)throw Error();process.kill(pid,0)}catch(e){if(e.code==='ESRCH'){await unlink(path);return acquireLock(path)}throw Error('Worker lock exists; inspect it before removing.')}throw Error('Worker is already running')}}
export async function runJob(job,config,request,{spawnAgent=spawn,gitRun=git,exec=execText,stopRequested=()=>false,heartbeatMs=20000,watchdogMs=1000,leaseGraceMs=60000,reason=null,filesWaitMs=300000}={}){
 if(!safeId(job.id)||!config.agents.includes(job.agent)||typeof job.repo!=='string'||!safeId(job.lease)||typeof job.prompt!=='string'||job.prompt.length>16000||!Number.isInteger(job.timeoutSeconds)||job.timeoutSeconds<30||job.timeoutSeconds>3600)throw Error('Job rejected by local policy');
 // Clone and fetch can outlast a heartbeat interval, so keep the execution lease alive while preparing.
 let cancelled=false,repo,base='HEAD',workspace=null,staged=null,note='';const keep=setInterval(()=>request({action:'heartbeat',jobId:job.id,lease:job.lease}).then(r=>{if(!r.continue)cancelled=true}).catch(()=>{}),heartbeatMs);
 try{
  if(job.repo!==WORKSPACE_REPO)try{
   const source=await resolveRepo(config,job.repo,exec);repo=await realpath(source.path);if(gitRun(repo,['rev-parse','--show-toplevel'])!==repo)throw Error('Allowed path must be the repository root');
   // ghq clones may be stale or on another branch; start from the fetched remote default branch.
   if(source.ghq){await exec('git',['-C',repo,'fetch','--quiet','origin'],300000);const head=()=>exec('git',['-C',repo,'rev-parse','--verify','--quiet','origin/HEAD^{commit}'],30000);base=await head().catch(async()=>{await exec('git',['-C',repo,'remote','set-head','origin','--auto'],60000);return head()})}
  }catch(e){
   // Policy still rejects; a repository that cannot be cloned or fetched falls back to a workspace with the sent files.
   if(/local policy|repository root/.test(e.message))throw e;repo=null;note='Repository unavailable; ran in a workspace instead. ';
  }
  const tag=jobDirectives(job.prompt).files;if(tag)staged=await stagedFiles(tag,reason,exec,Date.now()+filesWaitMs,()=>cancelled||stopRequested());
  if(!repo)workspace=await prepareWorkspace(job,staged,exec);
 }finally{clearInterval(keep)}
 if(cancelled||stopRequested())throw Error('Job cancelled before start');
 const branch=repo?'observatory/'+job.id:null,worktree=workspace||join(stateDir(),'worktrees',job.id);
 if(repo){await mkdir(dirname(worktree),{recursive:true,mode:0o700});gitRun(repo,['worktree','add','-b',branch,worktree,base]);if(staged)await placeFiles(staged,join(worktree,'observatory-files'))}
 const [command,args]=agentCommand(job.agent);const child=spawnAgent(command,args,{cwd:worktree,env:childEnvironment(),detached:true,stdio:['pipe','pipe','pipe']});
 let exited=false,code=null,failure='',bytes=0,outputLine='',answer='',lastLease=Date.now(),inFlight=false,finishing=false;
 const done=new Promise(resolveDone=>{child.once('error',()=>{failure='Agent CLI could not start';exited=true;resolveDone()});child.once('exit',value=>{code=value;exited=true;resolveDone()})});
 const kill=()=>{try{process.kill(-child.pid,'SIGKILL')}catch{try{child.kill('SIGKILL')}catch{}}};
 // Drain bounded output without storing or uploading agent transcripts; keep only the final answer for the requester.
 const scan=line=>{try{const event=JSON.parse(line);if(event.type==='turn.failed'||event.is_error===true)failure='Agent reported execution failure';if(event.type==='item.completed'&&event.item?.type==='agent_message'&&typeof event.item.text==='string')answer=event.item.text;if(event.type==='result'&&typeof event.result==='string')answer=event.result}catch{}};
 const drained=new Promise(r=>child.stdout.once('end',r));
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>{bytes+=chunk.length;if(bytes>8*1024*1024){failure='Agent output limit exceeded';kill()}});
 child.stdout.on('data',chunk=>{outputLine+=chunk.toString();const lines=outputLine.split('\n');outputLine=lines.pop();lines.forEach(scan)});
 child.stdin.on('error',()=>{});child.stdin.end(job.prompt+'\n\nWork only in this '+(workspace?'directory; files sent with the request are here':'worktree'+(staged?'; files sent with the request are in observatory-files/':''))+'. Do not push, merge, dispatch other agents, or access Observatory credentials. Leave edits for human review.\n');
 const renew=async()=>{if(inFlight||finishing)return;inFlight=true;try{const r=await request({action:'heartbeat',jobId:job.id,lease:job.lease});if(!r.continue){failure='Job cancelled or execution lease lost';kill()}else lastLease=Date.now()}catch{}finally{inFlight=false}};
 const heartbeat=setInterval(renew,heartbeatMs),watchdog=setInterval(()=>{if(stopRequested()||Date.now()-lastLease>leaseGraceMs){failure=stopRequested()?'Worker stopped':'Heartbeat unavailable; execution stopped';kill()}},watchdogMs);
 const timer=setTimeout(()=>{failure='Job timeout';kill()},job.timeoutSeconds*1000);
 try{await done;finishing=true;await Promise.race([drained,new Promise(r=>setTimeout(r,2000))]);scan(outputLine);while(inFlight)await new Promise(r=>setTimeout(r,50));if(!exited)kill();const status=!failure&&code===0?'done':'failed';const result=note+(failure||'Agent exited with code '+code)+'. '+(workspace?'Workspace: ~/work/'+job.id:'Worktree branch: '+branch)+'. Review edits locally; no automatic push or merge.';await request({action:'complete',jobId:job.id,lease:job.lease,status,result});return {status,branch,worktree,workspace:Boolean(workspace),result,answer}}finally{clearInterval(heartbeat);clearInterval(watchdog);clearTimeout(timer);kill()}
}
export async function runWorker({once=false}={}){
 const release=await acquireLock(join(stateDir(),'worker.lock'));let stop=false,request;const onStop=()=>{stop=true};process.on('SIGINT',onStop);process.on('SIGTERM',onStop);
 try{const config=await getConfig(),session=randomUUID();request=async body=>workerRequest({...body,deviceId:config.deviceId,session},await loadCredentials());
 const reason=await reasonIdentity();console.error(reason?'Reason Network address: '+reason.person+'/'+REASON_SESSION+'@'+reason.machine:'Reason Network unavailable; job replies and file transfer are disabled.');
 const repos=[WORKSPACE_REPO,...await availableRepos(config)];await request({action:'register',hostname:hostname().slice(0,120),specs:collectSpecs(),repos,agents:config.agents});console.error('Worker registered; repositories: '+repos.length);
 do{try{if(reason)await collectFiles(reason).catch(()=>console.error('Reason Network mailbox unavailable; retrying.'));await request({action:'heartbeat'});if(config.agents.length){const {job}=await request({action:'claim'});if(job){let outcome;try{outcome=await runJob(job,config,request,{stopRequested:()=>stop,reason})}catch{console.error('Job failed; inspect local worktree and connection.');outcome={status:'failed',result:'Local worker rejected the job or execution failed. Inspect local worker logs.'};await request({action:'complete',jobId:job.id,lease:job.lease,...outcome}).catch(()=>{})}await replyResult(job,outcome,reason).catch(()=>console.error('Reason Network reply failed.'))}}}catch{console.error('Worker communication failed; retrying. Credentials are hidden.')}if(once||stop)break;for(let i=0;i<20&&!stop;i++)await new Promise(r=>setTimeout(r,1000))}while(!stop);
 }finally{await request?.({action:'offline'}).catch(()=>{});process.off('SIGINT',onStop);process.off('SIGTERM',onStop);await release()}
}
export function systemdUnit(node,script,path,environment={}){const quote=s=>'"'+s.replaceAll('\\','\\\\').replaceAll('"','\\"').replaceAll('%','%%')+'"';return '[Unit]\nDescription=Agent Observatory worker\nAfter=network-online.target\n\n[Service]\nType=simple\nExecStart='+quote(node)+' '+quote(script)+' run\nEnvironment='+quote('PATH='+path)+'\n'+Object.entries(environment).map(([k,v])=>'Environment='+quote(k+'='+v)+'\n').join('')+'Restart=on-failure\nRestartSec=15\nUMask=0077\nKillMode=control-group\nTimeoutStopSec=10\n\n[Install]\nWantedBy=default.target\n'}
const xml=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
export function launchdPlist(node,script,path,log,environment={}){return '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict><key>Label</key><string>dev.observatory.worker</string><key>ProgramArguments</key><array>'+[node,script,'run'].map(x=>'<string>'+xml(x)+'</string>').join('')+'</array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>15</integer><key>EnvironmentVariables</key><dict><key>PATH</key><string>'+xml(path)+'</string>'+Object.entries(environment).map(([k,v])=>'<key>'+xml(k)+'</key><string>'+xml(v)+'</string>').join('')+'</dict><key>StandardOutPath</key><string>'+xml(log)+'</string><key>StandardErrorPath</key><string>'+xml(log)+'</string></dict></plist>\n'}
async function service(action){
 const script=await realpath(fileURLToPath(import.meta.url)),node=process.execPath,path=process.env.PATH||'/usr/bin:/bin';const environment={};for(const key of ['XDG_CONFIG_HOME','XDG_STATE_HOME','XDG_DATA_HOME','CODEX_HOME','CLAUDE_CONFIG_DIR'])if(process.env[key])environment[key]=process.env[key];
 if(platform()==='linux'){const unit=join(process.env.XDG_CONFIG_HOME||join(homedir(),'.config'),'systemd','user','observatory-worker.service');if(action==='install'){await mkdir(dirname(unit),{recursive:true});await writeFile(unit,systemdUnit(node,script,path,environment));execFileSync('systemctl',['--user','daemon-reload'],{stdio:'inherit'});execFileSync('systemctl',['--user','enable','observatory-worker.service'],{stdio:'inherit'});execFileSync('systemctl',['--user','restart','observatory-worker.service'],{stdio:'inherit'})}else execFileSync(action==='logs'?'journalctl':'systemctl',action==='logs'?['--user','-u','observatory-worker.service','-n','60','--no-pager']:['--user',...(action==='stop'?['disable','--now']: [action]),'observatory-worker.service'],{stdio:'inherit'});
 }else if(platform()==='darwin'){const file=join(homedir(),'Library','LaunchAgents','dev.observatory.worker.plist'),domain='gui/'+process.getuid(),label=domain+'/dev.observatory.worker';if(action==='install'){await mkdir(dirname(file),{recursive:true});await mkdir(stateDir(),{recursive:true,mode:0o700});await writeFile(file,launchdPlist(node,script,path,join(stateDir(),'worker.log'),environment),{mode:0o600});try{execFileSync('launchctl',['bootout',label],{stdio:'ignore'})}catch{}
  // bootout returns before the old job is fully removed; bootstrap fails with EIO until then.
  for(let i=0;;i++){try{execFileSync('launchctl',['bootstrap',domain,file],{stdio:i<9?'ignore':'inherit'});break}catch(e){if(i>=9)throw e;await new Promise(r=>setTimeout(r,500))}}}else if(action==='logs'){execFileSync('tail',['-n','60',join(stateDir(),'worker.log')],{stdio:'inherit'})}else execFileSync('launchctl',action==='status'?['print',label]:action==='start'?['bootstrap',domain,file]:['bootout',label],{stdio:'inherit'});
 }else throw Error('Service install supports Linux systemd and macOS launchd. Use worker run in other supervisors.');
}
// setup/update defaults fill only unset choices, so explicit `worker agents/owners` survive later updates.
export function applySyncDefaults(config,created,args){
 const option=name=>{const arg=args.find(a=>a.startsWith('--default-'+name+'='));return arg===undefined?undefined:arg.slice(name.length+11).split(',').filter(Boolean)};
 const agents=option('agents'),owners=option('owners');
 if(created&&agents)config.agents=agents;if(config.owners===undefined&&owners)config.owners=owners;
 return validateConfig(config);
}
export async function main(args=process.argv.slice(2)){
 const [action,...rest]=args;
 if(action==='init'){try{await readFile(configPath());console.error('Worker already configured; left untouched.');return}catch(e){if(e.code!=='ENOENT')throw e}const config={deviceId:randomUUID(),agents:[],repos:{}};await saveConfig(config);console.error('Created worker.json. Telemetry enabled; job execution requires worker agents. Repositories come from worker allow or worker owners; other jobs run in ~/work.');}
 else if(action==='allow'){const [alias,path]=rest;if(!alias||!path)throw Error('Usage: worker allow ALIAS /absolute/repository');const c=await getConfig();c.repos[alias]=await realpath(resolve(path));validateConfig(c);if(git(c.repos[alias],['rev-parse','--show-toplevel'])!==c.repos[alias])throw Error('Path must be a Git repository root');await saveConfig(c);console.error('Repository allowed. Restart worker to apply.');}
 else if(action==='agents'){const c=await getConfig();c.agents=rest;validateConfig(c);await saveConfig(c);console.error('Agents updated. Restart worker to apply.');}
 else if(action==='owners'){const c=await getConfig();c.owners=rest;validateConfig(c);await saveConfig(c);console.error('GitHub owners updated. Restart worker to apply.');}
 else if(action==='run')await runWorker({once:rest.includes('--once')});
 else if(action==='sync'){try{await readFile(join(configDir(),'worker-disabled'));console.error('Worker disabled; skipped.');return}catch(e){if(e.code!=='ENOENT')throw e}await loadCredentials();let created=false;try{await readFile(configPath())}catch(e){if(e.code!=='ENOENT')throw e;created=true}await main(['init']);await saveConfig(applySyncDefaults(await getConfig(),created,rest));await service('install')}
 else if(['install','start','stop','status','logs'].includes(action)){if(action==='install'||action==='start'){await getConfig();await loadCredentials();await unlink(join(configDir(),'worker-disabled')).catch(e=>{if(e.code!=='ENOENT')throw e})}if(action==='stop'){await mkdir(configDir(),{recursive:true});await writeFile(join(configDir(),'worker-disabled'),'disabled\n',{mode:0o600})}await service(action)}
 else throw Error('Usage: observatory worker init|allow ALIAS PATH|agents [codex claude]|owners [GITHUB_OWNER...]|run [--once]|install|start|stop|status|logs');
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){try{await main()}catch(error){console.error(error.message||'Worker failed');process.exitCode=1}}
