// Shared by the Supabase Edge Function and Node contract tests. No dependencies.
const contexts = new Set(['startup', 'practice', 'runtime', 'update', 'validation']);
export const codeNames = ['Unclassified error (message intentionally omitted)',
  'Index exceeds array bounds', 'Undefined function or variable', 'Incompatible array dimensions',
  'Incompatible matrix dimensions', 'Out of memory', 'Too many inputs', 'Too many outputs',
  'Not enough inputs', 'Not enough inputs', 'Too many inputs', 'File could not be read',
  'Invalid file handle', 'Assertion failed', 'Unclassified', 'Unclassified', 'Unclassified',
  'Unclassified', 'Unclassified', 'Unclassified', 'Update check unavailable',
  'Update installation or validation failed', 'Candidate validation failed'];
function exactKeys(value, keys) {
  return value && typeof value === 'object' && !Array.isArray(value) &&
    JSON.stringify(Object.keys(value).sort()) === JSON.stringify([...keys].sort());
}
export function catalogFor(catalog,release) {
  return [catalog,...(catalog.previous||[])].find(c=>c.release===release);
}
export function validateReport(r, catalog, now = Date.now()) {
  if (!exactKeys(r, ['schemaVersion','eventId','observedAt','release','matlabRelease','context','errorCode','frames',...(r?.schemaVersion===2?['update']:[])])) return false;
  catalog=catalogFor(catalog,r.release); if(!catalog) return false;
  if (![1,2].includes(r.schemaVersion) || r.release !== catalog.release || !/^[a-f0-9]{32}$/.test(r.eventId)) return false;
  if (typeof r.observedAt !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(r.observedAt)) return false;
  const time = Date.parse(r.observedAt);
  if (!Number.isFinite(time) || time > now + 86400000 || time < now - 30 * 86400000) return false;
  if (typeof r.matlabRelease !== 'string' || (!/^\d{4}[ab]$/.test(r.matlabRelease) && !(r.schemaVersion===2 && r.matlabRelease==='unknown')) || !contexts.has(r.context)) return false;
  if (r.schemaVersion===2 && (!['update','validation'].includes(r.context) || !validateUpdate(r.update,catalog))) return false;
  if (!Number.isInteger(r.errorCode) || r.errorCode < 0 || r.errorCode > 22) return false;
  if (!Array.isArray(r.frames) || r.frames.length > 8) return false;
  return r.frames.every(f => exactKeys(f,['sourceId','line']) && typeof f.sourceId === 'string' &&
    /^[a-f0-9]{32}$/.test(f.sourceId) && Object.hasOwn(catalog.sources,'s'+f.sourceId) &&
    Number.isInteger(f.line) && f.line >= 1 && f.line <= 1000000);
}
export function validateUpdate(d,catalog) {
  if (!exactKeys(d,['targetVersion','stage','component','reason','httpStatus','exitCode','systemCode','source','line','pluginFailures','matlabIdentifier','startupSignals','environment'])) return false;
  if (typeof d.targetVersion!=='string' || d.targetVersion.length>32 || !/^(unknown|\d+\.\d+\.\d+)$/.test(d.targetVersion)) return false;
  if (!['check','download','integrity','extract','install','startup','validation','practice','activate','worker'].includes(d.stage)) return false;
  if (!['unknown','network','http','tls','timeout','hash-mismatch','archive-invalid','access-denied','disk-full','path-too-long','file-in-use','matlab-launch','matlab-exit','validation-failed','metadata-invalid','source-missing'].includes(d.reason)) return false;
  if (!catalog.components?.includes(d.component)) return false;
  if (d.matlabIdentifier!=='' && !catalog.identifiers?.includes(d.matlabIdentifier)) return false;
  if (!Array.isArray(d.startupSignals) || d.startupSignals.length>6 || !d.startupSignals.every(s=>['license-failure','matlab-crash','missing-library','invalid-mex','missing-validation-function','out-of-memory'].includes(s))) return false;
  const e=d.environment;
  if (!exactKeys(e,['matlabVersion','windowsVersion','powershellVersion','architecture','freeDiskMB'])) return false;
  for (const key of ['matlabVersion','windowsVersion','powershellVersion']) if(typeof e[key]!=='string' || e[key].length>40 || !/^(unknown|\d+(\.\d+){1,4})$/.test(e[key])) return false;
  if (!['x64','x86','arm64','unknown'].includes(e.architecture) || !Number.isInteger(e.freeDiskMB) || e.freeDiskMB< -1 || e.freeDiskMB>1000000000) return false;
  if (!Number.isInteger(d.httpStatus) || (d.httpStatus!==0 && (d.httpStatus<100 || d.httpStatus>599))) return false;
  for (const key of ['exitCode','systemCode']) if (!Number.isInteger(d[key]) || d[key]<-2147483648 || d[key]>2147483647) return false;
  if (!Number.isInteger(d.line) || d.line<0 || d.line>1000000 || !['','Desktop-Common.ps1','Install-EEGLAB.ps1','Apply-DesktopUpdate.ps1','Update-Launch.ps1','Complete-DesktopSetup.ps1'].includes(d.source)) return false;
  return Array.isArray(d.pluginFailures) && d.pluginFailures.length<=60 && d.pluginFailures.every(p=>exactKeys(p,['component','reason']) && catalog.components.includes(p.component) && ['missing','unregistered','startup','version'].includes(p.reason));
}
export function updateSummary(d) {
  return '\n\nUpdate details (structured; no raw log):\n'+
    '- Target package: '+d.targetVersion+'\n- Failed step: '+d.stage+'\n- Component: '+d.component+
    '\n- Failure category: '+d.reason+'\n- HTTP status: '+d.httpStatus+'\n- Process exit code: '+d.exitCode+
    '\n- Windows HRESULT: '+d.systemCode+(d.source?'\n- Installer location: `'+d.source+'`, line '+d.line:'')+
    d.pluginFailures.map(p=>'\n- Plugin check: '+p.component+' — '+p.reason).join('')+
    (d.matlabIdentifier?'\n- MATLAB identifier: `'+d.matlabIdentifier+'`':'')+
    d.startupSignals.map(s=>'\n- Recognized startup message: '+s).join('')+
    '\n- MATLAB build: '+d.environment.matlabVersion+'\n- Windows API version: '+d.environment.windowsVersion+
    '\n- PowerShell: '+d.environment.powershellVersion+'\n- Process architecture: '+d.environment.architecture+
    '\n- Free installation-disk space (MB): '+d.environment.freeDiskMB;
}
async function boundedJson(request) {
  if (!request.headers.get('content-type')?.startsWith('application/json')) throw Error('invalid');
  const reader=request.body?.getReader(); if (!reader) throw Error('invalid');
  const chunks=[]; let size=0;
  try {
    while (true) {
      const {done,value}=await reader.read(); if(done) break;
      size+=value.length; if(size>8192) throw Error('invalid'); chunks.push(value);
    }
  } finally { await reader.cancel().catch(()=>{}); }
  const bytes=new Uint8Array(size); let offset=0;
  for(const chunk of chunks) { bytes.set(chunk,offset); offset+=chunk.length; }
  return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
}
export async function fingerprint(r) {
  const data=JSON.stringify([r.release,r.matlabRelease,r.context,r.errorCode,r.frames,...(r.schemaVersion===2?[
    r.update.targetVersion,r.update.stage,r.update.component,r.update.reason,r.update.httpStatus,r.update.exitCode,
    r.update.systemCode,r.update.source,r.update.line,r.update.pluginFailures,r.update.matlabIdentifier,r.update.startupSignals]:[])]);
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(data)))].map(x=>x.toString(16).padStart(2,'0')).join('');
}
const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
export function createHandler({store,catalog,authorize=async()=>false}) {
  return async request=>{
    const path=new URL(request.url).pathname.split('/').pop();
    try {
      if(path==='health' && request.method==='GET') return reply(200,{schemaVersion:1,release:catalog.release});
      if(path==='report' && request.method==='POST') {
        let report; try {report=await boundedJson(request);} catch {return reply(400,{accepted:false});}
        if(!validateReport(report,catalog)) return reply(400,{accepted:false});
        const result=await store.ingest(report,await fingerprint(report));
        return reply(result.accepted?202:429,{accepted:result.accepted===true});
      }
      if(!['claim','ack'].includes(path) || request.method!=='POST') return reply(404,{accepted:false});
      if(!await authorize(request)) return reply(401,{accepted:false});
      if(path==='claim') return reply(200,{groups:await store.claim()});
      let ack; try {ack=await boundedJson(request);} catch {return reply(400,{accepted:false});}
      if(!exactKeys(ack,['fingerprint','leaseToken','count','issueNumber']) ||
        !/^[a-f0-9]{64}$/.test(ack.fingerprint) || !/^[a-f0-9-]{36}$/.test(ack.leaseToken) ||
        !Number.isSafeInteger(ack.count) || ack.count<1 || !Number.isSafeInteger(ack.issueNumber) || ack.issueNumber<1) return reply(400,{accepted:false});
      return reply(200,{accepted:await store.ack(ack)});
    } catch {
      // No payload, exception, credential or path is reflected or logged.
      return reply(503,{accepted:false});
    }
  };
}
