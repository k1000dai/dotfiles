import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,readFile,writeFile,rm,stat} from 'node:fs/promises';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {execFileSync,spawn} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {validateConfig,collectSpecs,workerRequest,runJob,acquireLock,systemdUnit,launchdPlist,childEnvironment,agentCommand,main} from '../observatory-worker.mjs';
import {ORIGIN} from '../observatory-mcp.mjs';
const fixture={origin:ORIGIN,token:'obs_'+'a'.repeat(64),serviceToken:'fixture-private'};
test('worker transport pins origin and endpoint and forbids redirects',async()=>{
 const fetcher=async(url,options)=>{assert.equal(url,ORIGIN+'/api/worker');assert.equal(options.redirect,'error');assert.equal(options.headers['X-Observatory-Agent-Token'],fixture.token);return Response.json({ok:true})};
 assert.deepEqual(await workerRequest({action:'heartbeat'},fixture,fetcher),{ok:true});
 await assert.rejects(workerRequest({}, {...fixture,origin:'https://foreign.invalid'},()=>{throw Error('must not send')}),/destination/);
 await assert.rejects(workerRequest({},fixture,async()=>new Response('<html>')),/non-JSON/);
});
test('telemetry and local policy do not invent GPU memory or allow unknown executors',()=>{
 const specs=collectSpecs((cmd)=>{if(cmd==='nvidia-smi')return 'Fixture GPU, 8192\n';throw Error()});assert.equal(specs.gpus[0].vramBytes,8192*1048576);assert.ok(specs.cores>0);assert.ok(specs.memoryBytes>0);
 assert.throws(()=>validateConfig({deviceId:randomUUID(),agents:['shell'],repos:{}}));assert.throws(()=>validateConfig({deviceId:randomUUID(),agents:[],repos:{demo:'relative'}}));
 assert.equal(childEnvironment({PATH:'/bin',SOME_SECRET:'hidden'}).SOME_SECRET,undefined);assert.ok(agentCommand('codex')[1].includes('workspace-write'));assert.ok(agentCommand('claude')[1].includes('--restricted'));
});
test('config survives init, duplicate process lock fails, service paths are escaped',async()=>{
 const root=await mkdtemp(join(tmpdir(),'obs-worker-'));const old=process.env.XDG_CONFIG_HOME;process.env.XDG_CONFIG_HOME=root;
 try{await main(['init']);const file=join(root,'observatory','worker.json'),first=await readFile(file,'utf8');await main(['init']);assert.equal(await readFile(file,'utf8'),first);assert.equal((await stat(file)).mode&0o777,0o600);assert.deepEqual(JSON.parse(first).agents,[]);
 const unlock=await acquireLock(join(root,'worker.lock'));await assert.rejects(acquireLock(join(root,'worker.lock')),/already running/);await unlock();
 assert.match(systemdUnit('/node path','/repo%/worker.mjs','/bin'),/repo%%/);assert.match(launchdPlist('/node','/a&b/worker','/bin','/log'),/a&amp;b/);
 }finally{if(old===undefined)delete process.env.XDG_CONFIG_HOME;else process.env.XDG_CONFIG_HOME=old;await rm(root,{recursive:true,force:true})}
});
test('real worktree executes a fixture CLI, leaves changes and reports no transcript',async()=>{
 const root=await mkdtemp(join(tmpdir(),'obs-run-')),repo=join(root,'repo');await mkdir(repo);const previous=process.env.XDG_STATE_HOME;process.env.XDG_STATE_HOME=root;
 try{execFileSync('git',['init','-q',repo]);execFileSync('git',['-C',repo,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','--allow-empty','-qm','fixture']);
 const config={deviceId:randomUUID(),agents:['codex'],repos:{demo:repo}},job=()=>({id:randomUUID(),lease:randomUUID(),repo:'demo',agent:'codex',prompt:'Fixture',timeoutSeconds:30});const reports=[];
 const request=async data=>{reports.push(data);return {continue:true}};
 const execute=(_cmd,_args,options)=>spawn(process.execPath,['--input-type=module','-e',"import {writeFileSync} from 'node:fs';process.stdin.resume();process.stdin.on('end',()=>{writeFileSync('fixture.txt','edited');console.log('PRIVATE TRANSCRIPT')})"],options);
 const result=await runJob(job(),config,request,{spawnAgent:execute});assert.equal(result.status,'done');assert.equal(await readFile(join(result.worktree,'fixture.txt'),'utf8'),'edited');assert.equal(JSON.stringify(reports).includes('PRIVATE TRANSCRIPT'),false);assert.equal(reports.at(-1).action,'complete');
 let launched=false;await assert.rejects(runJob({...job(),repo:'forbidden'},config,request,{spawnAgent:()=>{launched=true}}),/policy/);assert.equal(launched,false);
 // Cancellation and loss of connectivity both kill the fixture process group.
 const hang=(_cmd,_args,options)=>spawn(process.execPath,['-e','process.stdin.resume();setInterval(()=>{},1000)'],options);
 const cancelled=[];await runJob(job(),config,async data=>{cancelled.push(data);return {continue:false}},{spawnAgent:hang,heartbeatMs:20,watchdogMs:10});assert.equal(cancelled.at(-1).status,'failed');assert.match(cancelled.at(-1).result,/cancelled/);
 const disconnected=[];await runJob(job(),config,async data=>{if(data.action==='heartbeat')throw Error('offline');disconnected.push(data);return {}},{spawnAgent:hang,heartbeatMs:20,watchdogMs:10,leaseGraceMs:100});assert.match(disconnected.at(-1).result,/Heartbeat unavailable/);
 }finally{if(previous===undefined)delete process.env.XDG_STATE_HOME;else process.env.XDG_STATE_HOME=previous;await rm(root,{recursive:true,force:true})}
});
