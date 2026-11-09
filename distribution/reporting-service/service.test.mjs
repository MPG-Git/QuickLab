import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler, validateReport, fingerprint } from './service.mjs';
import { collect } from './collect-reports.mjs';
const sourceId='a'.repeat(32), identityToken='test-only-'.repeat(6);
const catalog={release:'1.1.0',sources:{['s'+sourceId]:'eeglab2026.1.0/plugins/quicklab/example.m'}};
const fresh=()=>({schemaVersion:1,eventId:'b'.repeat(32),observedAt:new Date().toISOString(),release:'1.1.0',matlabRelease:'2023b',context:'runtime',errorCode:1,frames:[{sourceId,line:42}]});
const jsonResponse=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}});
test('Strict allowlist accepts technical data and rejects personal/free-text fields',()=>{
  assert.equal(validateReport(fresh(),catalog),true);
  const cases=[{...fresh(),message:'Participant Jane, EEG and C:\\Users\\Jane'},
    {...fresh(),frames:[{sourceId,line:42,file:'secret.set'}]},
    {...fresh(),frames:[{sourceId:'c'.repeat(32),line:42}]},
    {...fresh(),eventId:'patient-name'}, {...fresh(),context:'patient-name'},
    {...fresh(),matlabRelease:'secret'}, {...fresh(),errorCode:'MATLAB:private'},
    {...fresh(),frames:[{sourceId,line:NaN}]}, {...fresh(),frames:Array(9).fill({sourceId,line:42})},
    {...fresh(),observedAt:'2020-01-01T00:00:00.000Z'}, {...fresh(),release:'9.9.9'}];
  for(const value of cases) assert.equal(validateReport(value,catalog),false);
});
test('Fingerprint groups equivalent failures, separates release/context/code locations',async()=>{
  const a=fresh(), b={...fresh(),eventId:'c'.repeat(32)};
  assert.equal(await fingerprint(a),await fingerprint(b));
  assert.notEqual(await fingerprint(a),await fingerprint({...b,context:'startup'}));
  assert.notEqual(await fingerprint(a),await fingerprint({...b,frames:[{sourceId,line:43}]}));
});
test('Previous release catalogs keep queued reports deliverable after an update',()=>{
  const extended={...catalog,previous:[{...catalog,release:'1.0.9'}]};
  assert.equal(validateReport({...fresh(),release:'1.0.9'},extended),true);
  assert.equal(validateReport({...fresh(),release:'1.0.8'},extended),false);
});
test('Public handler persists valid report, rejects injection and large bodies before storage',async()=>{
  const received=[];
  const handler=createHandler({catalog,authorize:async r=>r.headers.get('authorization')==='Bearer '+identityToken,store:{ingest:async r=>{received.push(r);return {accepted:true};}}});
  const request=body=>new Request('https://test/report',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  assert.equal((await handler(request(fresh()))).status,202);
  assert.equal((await handler(request({...fresh(),rawLog:'secret'}))).status,400);
  assert.equal((await handler(request({large:'x'.repeat(9000)}))).status,400);
  assert.equal(received.length,1);
  assert.equal(JSON.stringify(received).includes('secret'),false);
});
test('Private delivery APIs require relay authentication, hide internal errors and support retry',async()=>{
  let claimed=0;
  const handler=createHandler({catalog,authorize:async r=>r.headers.get('authorization')==='Bearer '+identityToken,store:{claim:async()=>{claimed++;return [];},ingest:async()=>{throw Error('PRIVATE KEY secret');}}});
  assert.equal((await handler(new Request('https://test/claim',{method:'POST'}))).status,401);
  assert.equal(claimed,0);
  assert.equal((await handler(new Request('https://test/claim',{method:'POST',headers:{Authorization:'Bearer '+identityToken}}))).status,200);
  const failed=await handler(new Request('https://test/report',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(fresh())}));
  assert.equal(failed.status,503); assert.equal((await failed.text()).includes('secret'),false);
});
test('Quota rejection leaves the client able to retry',async()=>{
  const handler=createHandler({catalog,authorize:async r=>r.headers.get('authorization')==='Bearer '+identityToken,store:{ingest:async()=>({accepted:false})}});
  const result=await handler(new Request('https://test/report',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(fresh())}));
  assert.equal(result.status,429); assert.deepEqual(await result.json(),{accepted:false});
});
function deliveryFixture({privateRepo=true,issueNumber=null,ack=true}={}) {
  const calls=[], group={fingerprint:'d'.repeat(64),sample:fresh(),count:2,firstSeen:new Date().toISOString(),lastSeen:new Date().toISOString(),issueNumber,leaseToken:'11111111-1111-4111-8111-111111111111'};
  const request=async(url,options)=>{
    calls.push({url,options});
    if(url.endsWith('/repos/owner/support')) return jsonResponse({private:privateRepo});
    if(url.endsWith('/claim')) return jsonResponse({groups:[group]});
    if(url.includes('/search/issues')) return jsonResponse({items:[]});
    if(url.endsWith('/issues') && options.method==='POST') return jsonResponse({number:9});
    if(url.endsWith('/issues/9') && options.method==='GET') return jsonResponse({title:'[EEGLAB '+group.fingerprint+'] error'});
    if(url.endsWith('/issues/9') && options.method==='PATCH') return jsonResponse({number:9});
    if(url.endsWith('/ack')) return jsonResponse({accepted:ack});
    throw Error('Unexpected fixture request');
  };
  return {calls,args:{endpoint:'https://'+'a'.repeat(20)+'.supabase.co/functions/v1/eeglab-reports',identityToken,repo:'owner/support',githubToken:'TEST_GITHUB_TOKEN',catalog,request}};
}
test('GitHub collection creates a private issue then acknowledges; credentials stay on their own hosts',async()=>{
  const {calls,args}=deliveryFixture(); assert.equal(await collect(args),1);
  const created=calls.find(c=>c.url.endsWith('/issues'));
  const body=JSON.parse(created.options.body).body;
  assert.match(body,/Observations: 2/); assert.match(body,/example\.m/);
  assert.equal(calls.at(-1).url.endsWith('/ack'),true);
  for(const c of calls) assert.equal(c.options.headers.Authorization,c.url.startsWith('https://api.github.com')?'Bearer TEST_GITHUB_TOKEN':'Bearer '+identityToken);
});
test('Repeated reports update their existing issue',async()=>{
  const {calls,args}=deliveryFixture({issueNumber:9}); assert.equal(await collect(args),1);
  assert.equal(calls.some(c=>c.options.method==='PATCH'),true);
  assert.equal(calls.some(c=>c.url.endsWith('/issues') && c.options.method==='POST'),false);
});
test('Public repositories are refused before reports are retrieved',async()=>{
  const {calls,args}=deliveryFixture({privateRepo:false}); await assert.rejects(collect(args),/private repository/);
  assert.equal(calls.length,1);
});
test('Missing acknowledgment fails the run so the lease can retry later',async()=>{
  const {args}=deliveryFixture({ack:false}); await assert.rejects(collect(args),/acknowledgment/);
});
