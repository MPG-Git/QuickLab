import { createHandler } from './service.mjs';
import { createGitHubAuthorizer } from './github-identity.mjs';
import catalog from './diagnostic-sources.json' with { type: 'json' };

const url=Deno.env.get('SUPABASE_URL')!;
const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
async function rpc(name:string,body:unknown={}) {
  const response=await fetch(url+'/rest/v1/rpc/'+name,{
    method:'POST',headers:{apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json'},
    body:JSON.stringify(body),signal:AbortSignal.timeout(10000)
  });
  if(!response.ok) throw Error('Reporting store unavailable');
  return await response.json();
}
Deno.serve(createHandler({catalog,authorize:createGitHubAuthorizer({
  audience:url+'/functions/v1/eeglab-reports',repository:'MPG-Git/EEGLAB-Support',ownerId:'214007000'
}),store:{
  ingest:(report:unknown,fingerprint:string)=>rpc('eeglab_report_ingest',{p_report:report,p_fingerprint:fingerprint}),
  claim:()=>rpc('eeglab_report_claim'),
  ack:(ack:any)=>rpc('eeglab_report_ack',{p_fingerprint:ack.fingerprint,p_lease:ack.leaseToken,p_count:ack.count,p_issue:ack.issueNumber})
}}));
