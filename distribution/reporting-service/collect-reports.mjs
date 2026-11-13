import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { validateReport, codeNames, catalogFor, updateSummary } from './service.mjs';
import { requestGitHubIdentity } from './github-identity.mjs';

export async function collect({endpoint,identityToken,repo,githubToken,catalog,request=fetch}) {
  if(!/^https:\/\/[a-z0-9]{20}\.supabase\.co\/functions\/v1\/eeglab-reports$/.test(endpoint)) throw Error('Invalid reporting endpoint');
  if(!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo)) throw Error('Invalid support repository');
  const gh=async(path,method='GET',body)=>{
    const response=await request('https://api.github.com'+path,{method,headers:{Authorization:'Bearer '+githubToken,
      Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','Content-Type':'application/json'},
      ...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(15000)});
    if(!response.ok) throw Error('GitHub request failed: '+response.status);
    return await response.json();
  };
  const checkPrivate=async()=>{if((await gh('/repos/'+repo)).private!==true) throw Error('Reports require a private repository');};
  await checkPrivate();
  const relay=async(path,body={})=>{
    const response=await request(endpoint+'/'+path,{method:'POST',headers:{Authorization:'Bearer '+identityToken,'Content-Type':'application/json'},
      body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
    if(!response.ok) throw Error('Report queue unavailable: '+response.status);
    return await response.json();
  };
  const {groups}=await relay('claim');
  if(!Array.isArray(groups) || groups.length>20) throw Error('Invalid report batch');
  let delivered=0;
  for(const group of groups) {
    const r=group.sample;
    // A stored report can be older than the 30-day incoming acceptance window.
    if(!validateReport(r,catalog,Date.parse(r?.observedAt)) || !/^[a-f0-9]{64}$/.test(group.fingerprint) ||
      !Number.isSafeInteger(group.count) || group.count<1 || !/^[a-f0-9-]{36}$/.test(group.leaseToken) ||
      !Number.isFinite(Date.parse(group.firstSeen)) || !Number.isFinite(Date.parse(group.lastSeen))) throw Error('Invalid queued report');
    const marker='[EEGLAB '+group.fingerprint+']';
    let number=group.issueNumber;
    if(number!==null && (!Number.isSafeInteger(number) || number<1)) throw Error('Invalid issue number');
    if(!number) {
      // Recover after an interrupted create/ack. The DB lease serializes delivery.
      const query=encodeURIComponent('repo:'+repo+' is:issue in:title "'+group.fingerprint+'"');
      const found=await gh('/search/issues?q='+query+'&per_page=10');
      number=found.items.find(x=>x.title.startsWith(marker))?.number;
    }
    const reportCatalog=catalogFor(catalog,r.release);
    const lines=r.frames.map(f=>'- `'+reportCatalog.sources['s'+f.sourceId]+'`, line '+f.line).join('\n') || '- No location in shipped code was available.';
    const body='Automatically collected technical diagnostics. No raw log, exception message, recording or personal path is included.\n\n'+
      '- Package: '+r.release+'\n- MATLAB: R'+r.matlabRelease+'\n- Context: '+r.context+'\n- Error: '+codeNames[r.errorCode]+
      '\n- Observations: '+group.count+'\n- First received: '+new Date(group.firstSeen).toISOString()+
      '\n- Last received: '+new Date(group.lastSeen).toISOString()+'\n\nCode locations:\n'+lines+(r.schemaVersion===2?updateSummary(r.update):'')+
      '\n\nCounts are observations, not every occurrence. Repeated identical errors may be observed only once per session. A plugin may have handled the error; a report does not by itself prove the analysis failed.';
    await checkPrivate();
    if(number) {
      const existing=await gh('/repos/'+repo+'/issues/'+number);
      if(!existing.title.startsWith(marker)) throw Error('Issue ownership mismatch');
      await gh('/repos/'+repo+'/issues/'+number,'PATCH',{body});
    } else {
      const created=await gh('/repos/'+repo+'/issues','POST',{title:marker+' '+codeNames[r.errorCode],body});
      number=created.number;
    }
    const ack=await relay('ack',{fingerprint:group.fingerprint,leaseToken:group.leaseToken,count:group.count,issueNumber:number});
    if(ack.accepted!==true) throw Error('Report acknowledgment failed');
    delivered++;
  }
  return delivered;
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  try {
    const catalog=JSON.parse(await readFile(new URL('./diagnostic-sources.json',import.meta.url),'utf8'));
    const endpoint=process.env.REPORTING_ENDPOINT;
    const identity=await requestGitHubIdentity(endpoint,process.env);
    const count=await collect({endpoint,identityToken:identity,
      repo:process.env.GITHUB_REPOSITORY,githubToken:process.env.GITHUB_TOKEN,catalog});
    console.log('Technical report groups delivered: '+count);
  } catch(error) { console.error(error.message); process.exitCode=1; }
}
