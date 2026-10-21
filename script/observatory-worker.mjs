#!/usr/bin/env node
// Resident worker: one job at a time; no listening ports, shell interpolation or uploaded transcripts.
import {hostname,platform,arch,cpus,totalmem,loadavg,homedir} from 'node:os';
import {readFile,mkdir,writeFile,open,unlink,realpath} from 'node:fs/promises';
import {join,dirname,resolve} from 'node:path';
import {spawn,execFileSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {ORIGIN,loadCredentials} from './observatory-mcp.mjs';
export const configDir=()=>join(process.env.XDG_CONFIG_HOME||join(homedir(),'.config'),'observatory');
export const stateDir=()=>join(process.env.XDG_STATE_HOME||join(homedir(),'.local','state'),'observatory');
const configPath=()=>join(configDir(),'worker.json');
const safeId=id=>typeof id==='string'&&/^[a-f0-9-]{36}$/.test(id);
export function validateConfig(c){
 if(!c||!safeId(c.deviceId)||typeof c.repos!=='object'||!c.repos||Array.isArray(c.repos)||Object.entries(c.repos).some(([alias,path])=>!/^[-a-zA-Z0-9_]{1,80}$/.test(alias)||typeof path!=='string'||!path.startsWith('/'))||Object.keys(c.repos).length>30)throw Error('Invalid worker configuration');
 if(!Array.isArray(c.agents)||c.agents.some(a=>!['codex','claude'].includes(a)))throw Error('Invalid agents');
 return c;
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
export async function runJob(job,config,request,{spawnAgent=spawn,gitRun=git,stopRequested=()=>false,heartbeatMs=20000,watchdogMs=1000,leaseGraceMs=60000}={}){
 if(!safeId(job.id)||!config.agents.includes(job.agent)||!Object.hasOwn(config.repos,job.repo)||!safeId(job.lease)||typeof job.prompt!=='string'||job.prompt.length>16000||!Number.isInteger(job.timeoutSeconds)||job.timeoutSeconds<30||job.timeoutSeconds>3600)throw Error('Job rejected by local policy');
 const repo=await realpath(config.repos[job.repo]);if(gitRun(repo,['rev-parse','--show-toplevel'])!==repo)throw Error('Allowed path must be the repository root');
 const worktree=join(stateDir(),'worktrees',job.id),branch='observatory/'+job.id;await mkdir(dirname(worktree),{recursive:true,mode:0o700});gitRun(repo,['worktree','add','-b',branch,worktree,'HEAD']);
 const [command,args]=agentCommand(job.agent);const child=spawnAgent(command,args,{cwd:worktree,env:childEnvironment(),detached:true,stdio:['pipe','pipe','pipe']});
 let exited=false,code=null,failure='',bytes=0,outputLine='',lastLease=Date.now(),inFlight=false,finishing=false;
 const done=new Promise(resolveDone=>{child.once('error',()=>{failure='Agent CLI could not start';exited=true;resolveDone()});child.once('exit',value=>{code=value;exited=true;resolveDone()})});
 const kill=()=>{try{process.kill(-child.pid,'SIGKILL')}catch{try{child.kill('SIGKILL')}catch{}}};
 // Drain bounded output without storing or uploading agent transcripts.
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>{bytes+=chunk.length;if(bytes>8*1024*1024){failure='Agent output limit exceeded';kill()}});
 child.stdout.on('data',chunk=>{outputLine+=chunk.toString();const lines=outputLine.split('\n');outputLine=lines.pop();for(const line of lines){try{const event=JSON.parse(line);if(event.type==='turn.failed'||event.is_error===true)failure='Agent reported execution failure'}catch{}}});
 child.stdin.on('error',()=>{});child.stdin.end(job.prompt+'\n\nWork only in this worktree. Do not push, merge, dispatch other agents, or access Observatory credentials. Leave edits for human review.\n');
 const renew=async()=>{if(inFlight||finishing)return;inFlight=true;try{const r=await request({action:'heartbeat',jobId:job.id,lease:job.lease});if(!r.continue){failure='Job cancelled or execution lease lost';kill()}else lastLease=Date.now()}catch{}finally{inFlight=false}};
 const heartbeat=setInterval(renew,heartbeatMs),watchdog=setInterval(()=>{if(stopRequested()||Date.now()-lastLease>leaseGraceMs){failure=stopRequested()?'Worker stopped':'Heartbeat unavailable; execution stopped';kill()}},watchdogMs);
 const timer=setTimeout(()=>{failure='Job timeout';kill()},job.timeoutSeconds*1000);
 try{await done;finishing=true;while(inFlight)await new Promise(r=>setTimeout(r,50));if(!exited)kill();const status=!failure&&code===0?'done':'failed';const result=(failure||'Agent exited with code '+code)+'. Worktree branch: '+branch+'. Review edits locally; no automatic push or merge.';await request({action:'complete',jobId:job.id,lease:job.lease,status,result});return {status,branch,worktree}}finally{clearInterval(heartbeat);clearInterval(watchdog);clearTimeout(timer);kill()}
}
export async function runWorker({once=false}={}){
 const release=await acquireLock(join(stateDir(),'worker.lock'));let stop=false,request;const onStop=()=>{stop=true};process.on('SIGINT',onStop);process.on('SIGTERM',onStop);
 try{const config=await getConfig(),session=randomUUID();request=async body=>workerRequest({...body,deviceId:config.deviceId,session},await loadCredentials());
 await request({action:'register',hostname:hostname().slice(0,120),specs:collectSpecs(),repos:Object.keys(config.repos),agents:config.agents});console.error('Worker registered; repositories: '+Object.keys(config.repos).length);
 do{try{await request({action:'heartbeat'});if(config.agents.length&&Object.keys(config.repos).length){const {job}=await request({action:'claim'});if(job){try{await runJob(job,config,request,{stopRequested:()=>stop})}catch{console.error('Job failed; inspect local worktree and connection.');await request({action:'complete',jobId:job.id,lease:job.lease,status:'failed',result:'Local worker rejected the job or execution failed. Inspect local worker logs.'}).catch(()=>{})}}}}catch{console.error('Worker communication failed; retrying. Credentials are hidden.')}if(once||stop)break;for(let i=0;i<20&&!stop;i++)await new Promise(r=>setTimeout(r,1000))}while(!stop);
 }finally{await request?.({action:'offline'}).catch(()=>{});process.off('SIGINT',onStop);process.off('SIGTERM',onStop);await release()}
}
export function systemdUnit(node,script,path,environment={}){const quote=s=>'"'+s.replaceAll('\\','\\\\').replaceAll('"','\\"').replaceAll('%','%%')+'"';return '[Unit]\nDescription=Agent Observatory worker\nAfter=network-online.target\n\n[Service]\nType=simple\nExecStart='+quote(node)+' '+quote(script)+' run\nEnvironment='+quote('PATH='+path)+'\n'+Object.entries(environment).map(([k,v])=>'Environment='+quote(k+'='+v)+'\n').join('')+'Restart=on-failure\nRestartSec=15\nUMask=0077\nKillMode=control-group\nTimeoutStopSec=10\n\n[Install]\nWantedBy=default.target\n'}
const xml=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
export function launchdPlist(node,script,path,log,environment={}){return '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict><key>Label</key><string>dev.observatory.worker</string><key>ProgramArguments</key><array>'+[node,script,'run'].map(x=>'<string>'+xml(x)+'</string>').join('')+'</array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>15</integer><key>EnvironmentVariables</key><dict><key>PATH</key><string>'+xml(path)+'</string>'+Object.entries(environment).map(([k,v])=>'<key>'+xml(k)+'</key><string>'+xml(v)+'</string>').join('')+'</dict><key>StandardOutPath</key><string>'+xml(log)+'</string><key>StandardErrorPath</key><string>'+xml(log)+'</string></dict></plist>\n'}
async function service(action){
 const script=await realpath(fileURLToPath(import.meta.url)),node=process.execPath,path=process.env.PATH||'/usr/bin:/bin';const environment={};for(const key of ['XDG_CONFIG_HOME','XDG_STATE_HOME','XDG_DATA_HOME','CODEX_HOME','CLAUDE_CONFIG_DIR'])if(process.env[key])environment[key]=process.env[key];
 if(platform()==='linux'){const unit=join(process.env.XDG_CONFIG_HOME||join(homedir(),'.config'),'systemd','user','observatory-worker.service');if(action==='install'){await mkdir(dirname(unit),{recursive:true});await writeFile(unit,systemdUnit(node,script,path,environment));execFileSync('systemctl',['--user','daemon-reload'],{stdio:'inherit'});execFileSync('systemctl',['--user','enable','observatory-worker.service'],{stdio:'inherit'});execFileSync('systemctl',['--user','restart','observatory-worker.service'],{stdio:'inherit'})}else execFileSync(action==='logs'?'journalctl':'systemctl',action==='logs'?['--user','-u','observatory-worker.service','-n','60','--no-pager']:['--user',...(action==='stop'?['disable','--now']: [action]),'observatory-worker.service'],{stdio:'inherit'});
 }else if(platform()==='darwin'){const file=join(homedir(),'Library','LaunchAgents','dev.observatory.worker.plist'),domain='gui/'+process.getuid(),label=domain+'/dev.observatory.worker';if(action==='install'){await mkdir(dirname(file),{recursive:true});await mkdir(stateDir(),{recursive:true,mode:0o700});await writeFile(file,launchdPlist(node,script,path,join(stateDir(),'worker.log'),environment),{mode:0o600});try{execFileSync('launchctl',['bootout',label],{stdio:'ignore'})}catch{}execFileSync('launchctl',['bootstrap',domain,file],{stdio:'inherit'})}else if(action==='logs'){execFileSync('tail',['-n','60',join(stateDir(),'worker.log')],{stdio:'inherit'})}else execFileSync('launchctl',action==='status'?['print',label]:action==='start'?['bootstrap',domain,file]:['bootout',label],{stdio:'inherit'});
 }else throw Error('Service install supports Linux systemd and macOS launchd. Use worker run in other supervisors.');
}
export async function main(args=process.argv.slice(2)){
 const [action,...rest]=args;
 if(action==='init'){try{await readFile(configPath());console.error('Worker already configured; left untouched.');return}catch(e){if(e.code!=='ENOENT')throw e}const config={deviceId:randomUUID(),agents:[],repos:{}};await saveConfig(config);console.error('Created worker.json. Telemetry enabled; job execution requires worker allow and worker agents.');}
 else if(action==='allow'){const [alias,path]=rest;if(!alias||!path)throw Error('Usage: worker allow ALIAS /absolute/repository');const c=await getConfig();c.repos[alias]=await realpath(resolve(path));validateConfig(c);if(git(c.repos[alias],['rev-parse','--show-toplevel'])!==c.repos[alias])throw Error('Path must be a Git repository root');await saveConfig(c);console.error('Repository allowed. Restart worker to apply.');}
 else if(action==='agents'){const c=await getConfig();c.agents=rest;validateConfig(c);await saveConfig(c);console.error('Agents updated. Restart worker to apply.');}
 else if(action==='run')await runWorker({once:rest.includes('--once')});
 else if(action==='sync'){try{await readFile(join(configDir(),'worker-disabled'));console.error('Worker disabled; skipped.');return}catch(e){if(e.code!=='ENOENT')throw e}await loadCredentials();await main(['init']);await service('install')}
 else if(['install','start','stop','status','logs'].includes(action)){if(action==='install'||action==='start'){await getConfig();await loadCredentials();await unlink(join(configDir(),'worker-disabled')).catch(e=>{if(e.code!=='ENOENT')throw e})}if(action==='stop'){await mkdir(configDir(),{recursive:true});await writeFile(join(configDir(),'worker-disabled'),'disabled\n',{mode:0o600})}await service(action)}
 else throw Error('Usage: observatory worker init|allow ALIAS PATH|agents [codex claude]|run [--once]|install|start|stop|status|logs');
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){try{await main()}catch(error){console.error(error.message||'Worker failed');process.exitCode=1}}
