import test from 'node:test';
import assert from 'node:assert/strict';
import { createGitHubAuthorizer,requestGitHubIdentity } from './github-identity.mjs';
const keys=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
const publicKey={...await crypto.subtle.exportKey('jwk',keys.publicKey),kid:'fixture',alg:'RS256'};
const now=Math.floor(Date.now()/1000),audience='https://example.test/collector';
const base={iss:'https://token.actions.githubusercontent.com',aud:audience,repository:'owner/support',repository_owner_id:'123',repository_id:'456',
  repository_visibility:'private',ref:'refs/heads/main',event_name:'schedule',workflow_ref:'owner/support/.github/workflows/collect-reports.yml@refs/heads/main',
  sub:'repo:owner@123/support@456:ref:refs/heads/main',exp:now+300,iat:now,nbf:now};
const encode=value=>Buffer.from(JSON.stringify(value)).toString('base64url');
async function token(claims=base,header={typ:'JWT',alg:'RS256',kid:'fixture'}) {
  const data=encode(header)+'.'+encode(claims);
  const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',keys.privateKey,new TextEncoder().encode(data));
  return data+'.'+Buffer.from(signature).toString('base64url');
}
const request=async()=>Response.json({keys:[publicKey]});
const authorizer=()=>createGitHubAuthorizer({audience,repository:'owner/support',ownerId:'123',request});
const incoming=token=>new Request('https://example.test/claim',{headers:{Authorization:'Bearer '+token}});
test('GitHub RSA signature and exact workflow identity authorize the collector',async()=>assert.equal(await authorizer()(incoming(await token())),true));
test('Expired, wrong-audience, public, fork, other branch/workflow and recycled owner identities fail',async()=>{
  for(const patch of [{exp:now-90},{aud:'wrong'},{repository_visibility:'public'},{repository:'attacker/support'},
    {repository_owner_id:'999'},{ref:'refs/heads/untrusted'},{workflow_ref:'owner/support/.github/workflows/other.yml@refs/heads/main'},
    {event_name:'pull_request'},{sub:'repo:attacker/support:ref:refs/heads/main'},{nbf:now+100},{exp:now+10000}])
    assert.equal(await authorizer()(incoming(await token({...base,...patch}))),false);
});
test('Algorithm substitution and forged signatures are rejected',async()=>{
  assert.equal(await authorizer()(incoming(await token(base,{typ:'JWT',alg:'HS256',kid:'fixture'}))),false);
  const good=await token(); const altered=good.split('.'); altered[2]='a'.repeat(altered[2].length);
  assert.equal(await authorizer()(incoming(altered.join('.'))),false);
});
test('OIDC request credential goes only to the GitHub identity host',async()=>{
  let called=false;
  const value=await requestGitHubIdentity(audience,{ACTIONS_ID_TOKEN_REQUEST_URL:'https://example.actions.githubusercontent.com/token?x=1',ACTIONS_ID_TOKEN_REQUEST_TOKEN:'fixture'},async(url,options)=>{
    called=true;assert.equal(new URL(url).searchParams.get('audience'),audience);assert.equal(options.headers.Authorization,'Bearer fixture');return Response.json({value:'signed-token'});
  });
  assert.equal(called,true);assert.equal(value,'signed-token');
  await assert.rejects(requestGitHubIdentity(audience,{ACTIONS_ID_TOKEN_REQUEST_URL:'https://attacker.example/token'},async()=>{throw Error('Must not call')}),/Invalid GitHub/);
});
