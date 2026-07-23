create or replace function fact_write(
  p_namespace text, p_key text, p_value jsonb, p_observed_at timestamptz,
  p_origin text, p_supersedes uuid default null, p_asserted_by uuid default null,
  p_note text default null
  ) returns fact language plpgsql as $$
declare
cur fact; v_status text; v_revision integer; v_new fact;
v_reason text := null; v_detail text := null;
begin
if p_origin not in ('human','script','claude') then
v_reason := 'bad_origin'; v_detail := p_origin;
end if;

select * into cur from fact
where namespace = p_namespace and key = p_key and status = 'current';

if v_reason is null and cur.id is not null
and (p_supersedes is null or p_supersedes <> cur.id) then
v_reason := 'stale_supersedes';
v_detail := format('declared %s, current is %s (rev %s)',
  coalesce(p_supersedes::text,'null'), cur.id, cur.revision);
end if;

if v_reason is null and cur.id is null and p_supersedes is not null then
v_reason := 'supersedes_nonexistent'; v_detail := p_supersedes::text;
end if;

if v_reason is null and cur.id is not null and p_observed_at < cur.observed_at then
v_reason := 'older_observation';
v_detail := format('observed %s, current observed %s', p_observed_at, cur.observed_at);
end if;

if v_reason is not null then
insert into write_attempt(namespace, key, attempted_by, origin, reason, detail, payload)
values (p_namespace, p_key, p_asserted_by, p_origin, v_reason, v_detail, p_value);

insert into fact(namespace, key, revision, value, observed_at, asserted_by,
  origin, status, supersedes, note)
values (p_namespace, p_key, null, p_value, p_observed_at, p_asserted_by,
  case when p_origin in ('human','script','claude') then p_origin else 'script' end,
  'rejected', p_supersedes,
  coalesce(p_note,'') || ' [rejected: ' || v_reason || ']')
returning * into v_new;
return v_new;
end if;

v_status := case when p_origin = 'claude' then 'proposed' else 'current' end;

if v_status = 'current' then
v_revision := coalesce(cur.revision, 0) + 1;
if cur.id is not null then
update fact set status = 'superseded' where id = cur.id;
end if;
else
v_revision := null;
end if;

insert into fact(namespace, key, revision, value, observed_at, asserted_by,
  origin, status, supersedes, note)
values (p_namespace, p_key, v_revision, p_value, p_observed_at, p_asserted_by,
  p_origin, v_status, p_supersedes, p_note)
returning * into v_new;
return v_new;
end; $$;

create or replace function fact_promote(p_fact_id uuid, p_by uuid default null)
returns fact language plpgsql as $$
declare p fact; cur fact; v_new fact;
begin
select * into p from fact where id = p_fact_id;
if p.id is null then raise exception 'no such fact %', p_fact_id; end if;
if p.status <> 'proposed' then raise exception 'fact % is %, not proposed', p_fact_id, p.status; end if;

select * into cur from fact where namespace = p.namespace and key = p.key and status = 'current';

if cur.id is not null and p.observed_at < cur.observed_at then
insert into write_attempt(namespace, key, attempted_by, origin, reason, detail, payload)
values (p.namespace, p.key, p_by, 'human', 'promote_older_observation',
  format('proposal observed %s, current observed %s', p.observed_at, cur.observed_at), p.value);
return p;
end if;

if cur.id is not null then update fact set status = 'superseded' where id = cur.id; end if;

update fact set status='current', revision=coalesce(cur.revision,0)+1, supersedes=cur.id
where id = p_fact_id returning * into v_new;
return v_new;
end; $$;

create or replace function lease_acquire(
  p_target_handle text, p_task text, p_holder_handle text, p_minutes integer default 30
  ) returns lease language plpgsql as $$
declare t uuid; h uuid; l lease;
begin
select id into t from identity where handle = p_target_handle and kind = 'target';
if t is null then raise exception 'no registered target named %', p_target_handle; end if;
select id into h from identity where handle = p_holder_handle;

select * into l from lease where target = t and released_at is null and expires_at > now();
if l.id is not null then
raise exception 'target % is held by % until %', p_target_handle, l.task, l.expires_at;
end if;

update lease set released_at = now() where target = t and released_at is null and expires_at <= now();

insert into lease(target, task, holder, expires_at)
values (t, p_task, h, now() + make_interval(mins => p_minutes)) returning * into l;
return l;
end; $$;
