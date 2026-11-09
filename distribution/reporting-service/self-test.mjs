// Manual GitHub Actions validation. Only a fabricated technical event is used.
import { readFile } from 'node:fs/promises';
import { collect } from './collect-reports.mjs';
import { fingerprint } from './service.mjs';
const catalog=JSON.parse(await readFile(new URL('./diagnostic-sources.json',import.meta.url),'utf8'));
const source=Object.keys(catalog.sources).find(k=>catalog.sources[k]==='eeglab_desktop_start.m');
const sample={schemaVersion:1,eventId:'0'.repeat(32),observedAt:new Date().toISOString(),release:catalog.release,
  matlabRelease:'2023b',context:'validation',errorCode:22,frames:[{sourceId:source.slice(1),line:999999}]};
const fp=await fingerprint(sample);
let issueNumber=null, count=1;
const endpoint='https://'+'a'.repeat(20)+'.supabase.co/functions/v1/eeglab-reports';
const repo=process.env.GITHUB_REPOSITORY, githubToken=process.env.GITHUB_TOKEN;
const request=async(url,options)=>{
  if(url===endpoint+'/claim') return Response.json({groups:[{fingerprint:fp,sample,count,firstSeen:new Date().toISOString(),lastSeen:new Date().toISOString(),issueNumber,leaseToken:'00000000-0000-4000-8000-000000000000'}]});
  if(url===endpoint+'/ack') { issueNumber=JSON.parse(options.body).issueNumber; return Response.json({accepted:true}); }
  if(!url.startsWith('https://api.github.com/')) throw Error('Unexpected self-test destination');
  return await fetch(url,options);
};
try {
  const args={endpoint,identityToken:'SELF_TEST_ONLY'.repeat(4),repo,githubToken,catalog,request};
  if(await collect(args)!==1 || !issueNumber) throw Error('Synthetic creation failed');
  const original=issueNumber; count=2;
  if(await collect(args)!==1 || issueNumber!==original) throw Error('Synthetic grouping failed');
  const check=await fetch('https://api.github.com/repos/'+repo+'/issues/'+issueNumber,{headers:{Authorization:'Bearer '+githubToken}});
  if(!check.ok || !(await check.json()).body.includes('Observations: 2')) throw Error('Synthetic update missing');
  console.log('PASS: private GitHub issue creation and duplicate grouping. Issue #'+issueNumber);
} finally {
  if(issueNumber) {
    const closed=await fetch('https://api.github.com/repos/'+repo+'/issues/'+issueNumber,{
      method:'PATCH',headers:{Authorization:'Bearer '+githubToken,'Content-Type':'application/json'},
      body:JSON.stringify({title:'[EEGLAB '+fp+'] SYNTHETIC SELF-TEST — no user data',state:'closed',
        body:'Synthetic validation only. A fabricated event created this private issue, then a second observation updated the same issue to count 2. This does not test the hosted Supabase endpoint.'})
    });
    if(!closed.ok) throw Error('Could not close synthetic test issue');
  }
}
