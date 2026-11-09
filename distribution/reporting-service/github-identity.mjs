// Accept only short-lived, GitHub-signed identities for this private collector.
// No shared credential and no client-controlled issuer/JWKS URL are used.
const issuer='https://token.actions.githubusercontent.com';
function decode(part) {
  if(!/^[A-Za-z0-9_-]+$/.test(part)) throw Error('Invalid token');
  return Uint8Array.from(atob(part.replaceAll('-','+').replaceAll('_','/')),c=>c.charCodeAt(0));
}
export function createGitHubAuthorizer({audience,repository,ownerId,request=fetch,clock=Date.now}) {
  let cache=[], expires=0;
  return async incoming=>{
    try {
      const auth=incoming.headers.get('authorization')||'';
      if(!auth.startsWith('Bearer ') || auth.length>16384) return false;
      const parts=auth.slice(7).split('.'); if(parts.length!==3) return false;
      const header=JSON.parse(new TextDecoder().decode(decode(parts[0])));
      const claims=JSON.parse(new TextDecoder().decode(decode(parts[1])));
      if(header.alg!=='RS256' || header.typ!=='JWT' || typeof header.kid!=='string') return false;
      const now=Math.floor(clock()/1000);
      if(claims.iss!==issuer || claims.aud!==audience || claims.repository!==repository ||
        claims.repository_owner_id!==ownerId || claims.repository_visibility!=='private' ||
        claims.ref!=='refs/heads/main' || !['schedule','workflow_dispatch'].includes(claims.event_name) ||
        claims.workflow_ref!==repository+'/.github/workflows/collect-reports.yml@refs/heads/main') return false;
      if(!Number.isInteger(claims.exp)||!Number.isInteger(claims.iat)||!Number.isInteger(claims.nbf)||
        claims.exp<now-30 || claims.iat>now+30 || claims.nbf>now+30 || claims.exp-claims.iat>600 || claims.exp<=claims.iat) return false;
      const [owner,name]=repository.split('/');
      if(typeof claims.repository_id!=='string' || !/^\d+$/.test(claims.repository_id)) return false;
      const subject='repo:'+owner+'@'+ownerId+'/'+name+'@'+claims.repository_id+':ref:refs/heads/main';
      if(claims.sub!==subject && claims.sub!=='repo:'+repository+':ref:refs/heads/main') return false;
      if(clock()>expires || !cache.some(k=>k.kid===header.kid)) {
        const response=await request(issuer+'/.well-known/jwks',{signal:AbortSignal.timeout(10000)});
        if(!response.ok) return false;
        const body=await response.json(); if(!Array.isArray(body.keys)||body.keys.length>20) return false;
        cache=body.keys; expires=clock()+600000;
      }
      const key=cache.find(k=>k.kid===header.kid && k.kty==='RSA' && (!k.alg||k.alg==='RS256'));
      if(!key) return false;
      const imported=await crypto.subtle.importKey('jwk',key,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['verify']);
      return await crypto.subtle.verify('RSASSA-PKCS1-v1_5',imported,decode(parts[2]),new TextEncoder().encode(parts[0]+'.'+parts[1]));
    } catch { return false; }
  };
}

export async function requestGitHubIdentity(audience,env,request=fetch) {
  const url=new URL(env.ACTIONS_ID_TOKEN_REQUEST_URL);
  if(url.protocol!=='https:' || !url.hostname.endsWith('.actions.githubusercontent.com')) throw Error('Invalid GitHub identity endpoint');
  url.searchParams.set('audience',audience);
  const response=await request(url.toString(),{headers:{Authorization:'Bearer '+env.ACTIONS_ID_TOKEN_REQUEST_TOKEN},signal:AbortSignal.timeout(15000)});
  if(!response.ok) throw Error('GitHub identity request failed');
  const result=await response.json();
  if(typeof result.value!=='string' || result.value.length>16384) throw Error('Invalid GitHub identity response');
  return result.value;
}
