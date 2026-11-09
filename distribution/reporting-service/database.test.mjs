import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

test('Actual PostgreSQL migration: permissions, deduplication, leases, acknowledgment and daily limit',async()=>{
  const db=new PGlite();
  try {
    await db.exec('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;');
    await db.exec(await readFile(new URL('./migration.sql',import.meta.url),'utf8'));
    const fp='a'.repeat(64), other='b'.repeat(64);
    const ingest=async(id,fingerprint=fp)=>(await db.query('select public.eeglab_report_ingest($1::jsonb,$2) as result',[JSON.stringify({eventId:id}),fingerprint])).rows[0].result;
    assert.equal((await ingest('1'.repeat(32))).accepted,true);
    assert.equal((await ingest('1'.repeat(32))).accepted,true);
    assert.equal((await ingest('1'.repeat(32),other)).accepted,false);
    assert.equal(Number((await db.query('select occurrences from public.eeglab_report_groups')).rows[0].occurrences),1);
    assert.equal((await ingest('2'.repeat(32))).accepted,true);
    const claim=async()=>(await db.query('select public.eeglab_report_claim() as result')).rows[0].result;
    const [group]=await claim(); assert.equal(group.count,2); assert.equal((await claim()).length,0);
    await ingest('3'.repeat(32));
    const ack=async(lease,count)=>(await db.query('select public.eeglab_report_ack($1,$2::uuid,$3,9) as result',[fp,lease,count])).rows[0].result;
    assert.equal(await ack('00000000-0000-0000-0000-000000000000',2),false);
    assert.equal(await ack(group.leaseToken,99),false);
    assert.equal(await ack(group.leaseToken,2),true);
    const [later]=await claim(); assert.equal(later.count,3);
    assert.equal(await ack(later.leaseToken,3),true);
    assert.equal((await claim()).length,0);
    await db.exec('set role anon');
    await assert.rejects(db.query('select * from public.eeglab_report_groups'),/permission denied/);
    await assert.rejects(db.query('select public.eeglab_report_claim()'),/permission denied/);
    await db.exec('reset role; set role service_role');
    assert.equal((await claim()).length,0);
    await db.exec('reset role');
    for(let i=4;i<=250;i++) assert.equal((await ingest(i.toString(16).padStart(32,'0'))).accepted,true);
    assert.equal((await ingest('f'.repeat(32))).accepted,false);
    // A retry remains idempotent even after the new-event quota is exhausted.
    assert.equal((await ingest('1'.repeat(32))).accepted,true);
    assert.equal(Number((await db.query('select used from public.eeglab_report_quota')).rows[0].used),250);
  } finally { await db.close(); }
});
