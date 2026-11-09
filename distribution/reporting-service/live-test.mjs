// Manual deployment check: fabricated records only, through the real service.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { collect } from './collect-reports.mjs';
import { requestGitHubIdentity } from './github-identity.mjs';
const endpoint=process.env.REPORTING_ENDPOINT;
const repo=process.env.GITHUB_REPOSITORY, githubToken=process.env.GITHUB_TOKEN;
const catalog=JSON.parse(await readFile(new URL('./diagnostic-sources.json',import.meta.url),'utf8'));
const source=Object.keys(catalog.sources).find(k=>catalog.sources[k]==='eeglab_desktop_start.m');
const sample={schemaVersion:1,eventId:randomUUID().replaceAll('-',''),observedAt:new Date().toISOString(),
  release:catalog.release,matlabRelease:'2023b',context:'validation',errorCode:22,
  frames:[{sourceId:source.slice(1),line:100000+(Number(process.env.GITHUB_RUN_ID)%800000)}]};
const identityToken=await requestGitHubIdentity(endpoint,process.env);
let issueNumber;
const request=async(url,options)=>{
  const result=await fetch(url,options);
  if(url===endpoint+'/ack' && result.ok) issueNumber=JSON.parse(options.body).issueNumber;
  return result;
};
const github=async(method,path,body)=>{
  const result=await fetch('https://api.github.com/repos/'+repo+path,{method,
    headers:{Authorization:'Bearer '+githubToken,'Content-Type':'application/json'},
    body:body===undefined?undefined:JSON.stringify(body)});
  assert.ok(result.ok,'GitHub request failed: '+result.status); return result.json();
};
try {
  assert.equal((await fetch(endpoint+'/claim',{method:'POST'})).status,401);
  assert.equal((await fetch(endpoint+'/report',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({...sample,message:'SYNTHETIC_PRIVATE_SENTINEL'})})).status,400);
  const send=async()=>assert.equal((await fetch(endpoint+'/report',{method:'POST',
    headers:{'Content-Type':'application/json'},body:JSON.stringify(sample)})).status,202);
  const args={endpoint,identityToken,repo,githubToken,catalog,request};
  await send(); await send(); // Delivery retry must not count a second event.
  assert.ok(await collect(args)>=1); assert.ok(issueNumber);
  const original=issueNumber;
  assert.match((await github('GET','/issues/'+issueNumber)).body,/Observations: 1/);
  sample.eventId=randomUUID().replaceAll('-',''); await send();
  assert.ok(await collect(args)>=1); assert.equal(issueNumber,original);
  const issue=await github('GET','/issues/'+issueNumber);
  assert.match(issue.body,/Observations: 2/);
  assert.ok(!issue.body.includes('SYNTHETIC_PRIVATE_SENTINEL'));
  await github('PATCH','/issues/'+issueNumber,{state:'closed',
    title:issue.title+' — SYNTHETIC LIVE TEST',
    body:issue.body+'\n\n**SYNTHETIC LIVE TEST — no user data.** Verified Supabase intake, rejected free text and unauthorized access, GitHub OIDC delivery, retry deduplication, and grouping to count 2.'});
  console.log('PASS: live Supabase → private GitHub issue, deduplication and grouping. '+issue.html_url);
} catch(error) {
  console.error('Live integration check failed. Synthetic issue, if created: '+(issueNumber||'none'));
  throw error;
}
