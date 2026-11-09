-- Use a dedicated Supabase project. Only the Edge Function's service role can
-- access these tables/RPCs. The public client never receives that credential.
begin;
create table public.eeglab_report_groups (
  fingerprint text primary key check (fingerprint ~ '^[a-f0-9]{64}$'),
  sample jsonb not null, occurrences bigint not null default 1,
  first_seen timestamptz not null default now(), last_seen timestamptz not null default now(),
  delivered_count bigint not null default 0, issue_number bigint,
  lease_token uuid, lease_until timestamptz
);
create table public.eeglab_report_events (
  event_id text primary key check (event_id ~ '^[a-f0-9]{32}$'),
  fingerprint text not null, received_at timestamptz not null default now()
);
create table public.eeglab_report_quota (day date primary key, used integer not null);
alter table public.eeglab_report_groups enable row level security;
alter table public.eeglab_report_events enable row level security;
alter table public.eeglab_report_quota enable row level security;
revoke all on public.eeglab_report_groups,public.eeglab_report_events,public.eeglab_report_quota from public,anon,authenticated;

create function public.eeglab_report_ingest(p_report jsonb,p_fingerprint text) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare existing text; used_count integer;
begin
  perform pg_advisory_xact_lock(1900911001);
  select fingerprint into existing from public.eeglab_report_events where event_id=p_report->>'eventId';
  if found then return jsonb_build_object('accepted',existing=p_fingerprint); end if;
  delete from public.eeglab_report_events where received_at < now()-interval '90 days';
  delete from public.eeglab_report_groups where last_seen < now()-interval '90 days';
  delete from public.eeglab_report_quota where day < current_date-7;
  select used into used_count from public.eeglab_report_quota where day=current_date;
  if coalesce(used_count,0)>=250 then return jsonb_build_object('accepted',false); end if;
  insert into public.eeglab_report_quota values(current_date,1)
    on conflict(day) do update set used=public.eeglab_report_quota.used+1;
  insert into public.eeglab_report_events(event_id,fingerprint) values(p_report->>'eventId',p_fingerprint);
  insert into public.eeglab_report_groups(fingerprint,sample) values(p_fingerprint,p_report)
    on conflict(fingerprint) do update set occurrences=public.eeglab_report_groups.occurrences+1,last_seen=now();
  return jsonb_build_object('accepted',true);
end $$;

create function public.eeglab_report_claim() returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
  with candidates as (
    select fingerprint from public.eeglab_report_groups
    where occurrences>delivered_count and (lease_until is null or lease_until<now())
    order by first_seen limit 20 for update skip locked
  ), claimed as (
    update public.eeglab_report_groups g set lease_token=gen_random_uuid(),lease_until=now()+interval '10 minutes'
    from candidates c where g.fingerprint=c.fingerprint returning g.*
  ) select coalesce(jsonb_agg(jsonb_build_object(
    'fingerprint',fingerprint,'sample',sample,'count',occurrences,'firstSeen',first_seen,
    'lastSeen',last_seen,'issueNumber',issue_number,'leaseToken',lease_token)), '[]'::jsonb)
    into result from claimed;
  return result;
end $$;

create function public.eeglab_report_ack(p_fingerprint text,p_lease uuid,p_count bigint,p_issue bigint) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  update public.eeglab_report_groups set delivered_count=greatest(delivered_count,p_count),
    issue_number=p_issue,lease_until=null,lease_token=null
    where fingerprint=p_fingerprint and lease_token=p_lease and p_count>=1 and p_count<=occurrences and p_issue>=1;
  return found;
end $$;
revoke all on function public.eeglab_report_ingest(jsonb,text),public.eeglab_report_claim(),public.eeglab_report_ack(text,uuid,bigint,bigint) from public,anon,authenticated;
grant execute on function public.eeglab_report_ingest(jsonb,text),public.eeglab_report_claim(),public.eeglab_report_ack(text,uuid,bigint,bigint) to service_role;
commit;
