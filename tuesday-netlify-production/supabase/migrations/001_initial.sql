-- TUESDAY ENTREPRENEURSHIP — PostgreSQL / Supabase migration v1
-- Run ONCE in a new Supabase project using SQL Editor.
-- Manual payment verification is required: a clicked payment link is NOT proof of payment.
create extension if not exists pgcrypto;

create type public.staff_role as enum ('owner','admin','reviewer','checkin');
create type public.event_status as enum ('draft','published','closed','cancelled');
create type public.booking_state as enum ('awaiting_payment','pending_review','needs_info','approved','rejected','cancelled');
create type public.payment_state as enum ('not_required','pending','reported','verified','failed','refunded');
create type public.ticket_state as enum ('active','used','revoked');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default 'مشارك جديد' check (char_length(trim(full_name)) between 2 and 120),
 email text,
 phone text check (phone is null or char_length(phone) between 8 and 24),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table public.staff_members (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role public.staff_role not null,
 active boolean not null default true,
 created_at timestamptz not null default now()
);

create table public.events (
 id uuid primary key default gen_random_uuid(),
 slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
 title text not null check (char_length(trim(title)) between 5 and 180),
 subtitle text not null default '',
 description text not null default '',
 speaker text not null default '',
 image_url text,
 venue_name text not null default '',
 maps_url text check (maps_url is null or maps_url ~* '^https://'),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 capacity integer not null check (capacity between 1 and 50000),
 price_sar numeric(10,2) not null default 0 check (price_sar >= 0),
 payment_url text check (payment_url is null or payment_url ~* '^https://'),
 status public.event_status not null default 'draft',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint valid_dates check (ends_at > starts_at),
 constraint paid_has_url check (price_sar = 0 or payment_url is not null)
);
create index events_published_starts on public.events(starts_at) where status='published';

create table public.bookings (
 id uuid primary key default gen_random_uuid(),
 event_id uuid not null references public.events(id),
 user_id uuid not null references public.profiles(id),
 state public.booking_state not null,
 payment_status public.payment_state not null,
 price_sar numeric(10,2) not null,
 payment_url_snapshot text,
 hold_until timestamptz,
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 review_note text,
 approved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(event_id,user_id)
);
create index bookings_event_state on public.bookings(event_id,state);
create index bookings_user_created on public.bookings(user_id,created_at desc);

create table public.payment_submissions (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null references public.bookings(id),
 reference text not null check (char_length(trim(reference)) between 3 and 160),
 note text not null default '',
 status text not null default 'reported' check (status in ('reported','verified','rejected')),
 verified_by uuid references auth.users(id),
 verified_at timestamptz,
 created_at timestamptz not null default now()
);
create unique index payment_reference_verified_unique on public.payment_submissions(lower(reference)) where status='verified';

create table public.tickets (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null unique references public.bookings(id),
 event_id uuid not null references public.events(id),
 state public.ticket_state not null default 'active',
 used_at timestamptz,
 used_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);

create table public.checkins (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null unique references public.bookings(id),
 ticket_id uuid not null unique references public.tickets(id),
 event_id uuid not null references public.events(id),
 staff_user_id uuid not null references auth.users(id),
 checked_in_at timestamptz not null default now()
);
create index checkins_event_time on public.checkins(event_id,checked_in_at desc);

create table public.scan_attempts (
 id bigint generated always as identity primary key,
 ticket_id uuid references public.tickets(id),
 staff_user_id uuid not null references auth.users(id),
 result text not null,
 created_at timestamptz not null default now()
);

create table public.refund_cases (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null unique references public.bookings(id),
 status text not null default 'pending' check (status in ('pending','completed')),
 reason text not null default '',
 completed_by uuid references auth.users(id),
 completed_at timestamptz,
 created_at timestamptz not null default now()
);

create table public.audit_logs (
 id bigint generated always as identity primary key,
 actor uuid references auth.users(id),
 action text not null,
 subject_id uuid,
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index audit_logs_created on public.audit_logs(created_at desc);

-- Account provisioning happens in database, not in the front-end.
create or replace function public.on_new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,full_name,email)
 values (new.id,coalesce(nullif(left(trim(new.raw_user_meta_data->>'full_name'),120),''),'مشارك جديد'),new.email)
 on conflict (id) do nothing;
 return new;
end; $$;
create trigger handle_auth_new_user after insert on auth.users for each row execute procedure public.on_new_user();

-- All privileged helpers validate the JWT inside PostgreSQL.
create or replace function public.has_role(allowed text[]) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.staff_members s where s.user_id=(select auth.uid()) and s.active and s.role::text=any(allowed));
$$;

alter table public.profiles enable row level security;
alter table public.staff_members enable row level security;
alter table public.events enable row level security;
alter table public.bookings enable row level security;
alter table public.payment_submissions enable row level security;
alter table public.tickets enable row level security;
alter table public.checkins enable row level security;
alter table public.scan_attempts enable row level security;
alter table public.audit_logs enable row level security;
alter table public.refund_cases enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (id=(select auth.uid()) or public.has_role(array['owner','admin','reviewer']));
create policy profiles_self_update on public.profiles for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
-- Disallow changing identity/email from client-side profile updates.
revoke update on public.profiles from authenticated;
grant update (full_name,phone) on public.profiles to authenticated;

create policy staff_read on public.staff_members for select to authenticated using (user_id=(select auth.uid()) or public.has_role(array['owner','admin']));
create policy events_public_read on public.events for select to anon,authenticated using (status='published' or public.has_role(array['owner','admin','reviewer','checkin']));
create policy events_admin_insert on public.events for insert to authenticated with check (public.has_role(array['owner','admin']));
create policy events_admin_update on public.events for update to authenticated using (public.has_role(array['owner','admin'])) with check (public.has_role(array['owner','admin']));
create policy bookings_read on public.bookings for select to authenticated using (user_id=(select auth.uid()) or public.has_role(array['owner','admin','reviewer']));
create policy payments_read on public.payment_submissions for select to authenticated using (exists(select 1 from public.bookings b where b.id=booking_id and b.user_id=(select auth.uid())) or public.has_role(array['owner','admin','reviewer']));
create policy tickets_read on public.tickets for select to authenticated using (exists(select 1 from public.bookings b where b.id=booking_id and b.user_id=(select auth.uid())) or public.has_role(array['owner','admin','reviewer']));
create policy checkins_read on public.checkins for select to authenticated using (exists(select 1 from public.bookings b where b.id=booking_id and b.user_id=(select auth.uid())) or public.has_role(array['owner','admin','reviewer']));
create policy scans_staff_read on public.scan_attempts for select to authenticated using (public.has_role(array['owner','admin','reviewer']));
create policy audit_staff_read on public.audit_logs for select to authenticated using (public.has_role(array['owner','admin']));
create policy refunds_staff_read on public.refund_cases for select to authenticated using (public.has_role(array['owner','admin','reviewer']));

-- Admin uploaded images. Keep it a dedicated PUBLIC bucket; never put personal documents in this bucket.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('event-images','event-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy event_images_read on storage.objects for select to anon,authenticated using(bucket_id='event-images');
create policy event_images_write on storage.objects for insert to authenticated with check(bucket_id='event-images' and public.has_role(array['owner','admin']));
create policy event_images_delete on storage.objects for delete to authenticated using(bucket_id='event-images' and public.has_role(array['owner','admin']));

-- Seat capacity includes pending approvals and unexpired payment holds.
-- Event row lock serializes competing registration attempts.
create or replace function public.create_booking(p_event uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare e public.events%rowtype; b uuid; occupied integer; u uuid:=auth.uid(); nm text; ph text;
begin
 if u is null then raise exception 'AUTH_REQUIRED'; end if;
 select full_name,phone into nm,ph from public.profiles where id=u;
 if nm is null or trim(nm)='مشارك جديد' or ph is null then raise exception 'PROFILE_INCOMPLETE'; end if;
 select * into e from public.events where id=p_event for update;
 if not found or e.status<>'published' or e.starts_at<=now() then raise exception 'EVENT_UNAVAILABLE'; end if;
 select id into b from public.bookings where event_id=p_event and user_id=u;
 if found then return b; end if;
 select count(*) into occupied from public.bookings
 where event_id=p_event and (state in ('approved','pending_review') or (state='awaiting_payment' and hold_until>now()));
 if occupied>=e.capacity then raise exception 'EVENT_FULL'; end if;
 insert into public.bookings(event_id,user_id,state,payment_status,price_sar,payment_url_snapshot,hold_until)
 values(e.id,u,case when e.price_sar=0 then 'pending_review'::public.booking_state else 'awaiting_payment'::public.booking_state end,
 case when e.price_sar=0 then 'not_required'::public.payment_state else 'pending'::public.payment_state end,
 e.price_sar,e.payment_url,case when e.price_sar>0 then now()+interval '30 minutes' end) returning id into b;
 insert into public.audit_logs(actor,action,subject_id) values(u,'booking.created',b);
 return b;
end; $$;

create or replace function public.report_payment(p_booking uuid,p_reference text,p_note text default '') returns void
language plpgsql security definer set search_path='' as $$
declare b public.bookings%rowtype; occupied integer; max_seats integer; previous integer;
begin
 select * into b from public.bookings where id=p_booking and user_id=auth.uid() for update;
 if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
 if b.price_sar<=0 or b.state not in ('awaiting_payment','needs_info','pending_review') or b.payment_status='verified' then raise exception 'PAYMENT_REPORT_UNAVAILABLE'; end if;
 if char_length(trim(p_reference))<3 or char_length(p_reference)>160 then raise exception 'INVALID_PAYMENT_REFERENCE'; end if;
 select count(*) into previous from public.payment_submissions where booking_id=b.id and created_at > now()-interval '1 hour';
 if previous>=3 then raise exception 'RATE_LIMIT'; end if;
 -- If payment hold expired, verify capacity again before restoring the reservation to the review queue.
 perform 1 from public.events where id=b.event_id for update;
 select capacity into max_seats from public.events where id=b.event_id;
 select count(*) into occupied from public.bookings where event_id=b.event_id and id<>b.id
 and (state in ('approved','pending_review') or (state='awaiting_payment' and hold_until>now()));
 if occupied>=max_seats then raise exception 'EVENT_FULL_CONTACT_SUPPORT'; end if;
 insert into public.payment_submissions(booking_id,reference,note) values(b.id,trim(p_reference),left(coalesce(p_note,''),500));
 update public.bookings set state='pending_review',payment_status='reported',hold_until=null,updated_at=now() where id=b.id;
 insert into public.audit_logs(actor,action,subject_id) values(auth.uid(),'payment.reported',b.id);
end; $$;

create or replace function public.verify_payment(p_submission uuid) returns void
language plpgsql security definer set search_path='' as $$
declare p public.payment_submissions%rowtype; b public.bookings%rowtype;
begin
 if not public.has_role(array['owner','admin','reviewer']) then raise exception 'FORBIDDEN'; end if;
 select * into p from public.payment_submissions where id=p_submission for update;
 if not found or p.status<>'reported' then raise exception 'INVALID_PAYMENT_SUBMISSION'; end if;
 select * into b from public.bookings where id=p.booking_id for update;
 if b.price_sar<=0 or b.payment_status='verified' or b.state not in ('pending_review','needs_info') then raise exception 'INVALID_BOOKING_STATE'; end if;
 -- Reviewer must manually confirm provider status, currency and exact amount outside the site.
 update public.payment_submissions set status='verified',verified_by=auth.uid(),verified_at=now() where id=p.id;
 update public.bookings set payment_status='verified',state='pending_review',updated_at=now() where id=b.id;
 insert into public.audit_logs(actor,action,subject_id,details) values(auth.uid(),'payment.verified',b.id,jsonb_build_object('submission_id',p.id));
end; $$;

create or replace function public.decide_booking(p_booking uuid,p_decision text,p_note text default '') returns void
language plpgsql security definer set search_path='' as $$
declare b public.bookings%rowtype; other_count integer;
begin
 if not public.has_role(array['owner','admin','reviewer']) then raise exception 'FORBIDDEN'; end if;
 if p_decision not in ('approve','reject','needs_info') then raise exception 'BAD_DECISION'; end if;
 select * into b from public.bookings where id=p_booking for update;
 if not found or b.state not in ('pending_review','needs_info') then raise exception 'INVALID_BOOKING_STATE'; end if;
 if p_decision='approve' then
  if exists(select 1 from public.events where id=b.event_id and (status in ('cancelled','closed') or starts_at<=now())) then raise exception 'EVENT_UNAVAILABLE'; end if;
  if b.payment_status not in ('verified','not_required') then raise exception 'PAYMENT_NOT_VERIFIED'; end if;
  -- Event lock serializes approval and booking creation.
  perform 1 from public.events where id=b.event_id for update;
  select count(*) into other_count from public.bookings where event_id=b.event_id and id<>b.id and state='approved';
  if other_count >= (select capacity from public.events where id=b.event_id) then raise exception 'EVENT_FULL'; end if;
  update public.bookings set state='approved',approved_at=now(),reviewed_at=now(),reviewed_by=auth.uid(),review_note=left(p_note,1000),updated_at=now() where id=b.id;
  insert into public.tickets(booking_id,event_id) values(b.id,b.event_id) on conflict(booking_id) do nothing;
 else
  update public.bookings set state=case when p_decision='reject' then 'rejected'::public.booking_state else 'needs_info'::public.booking_state end,
  reviewed_by=auth.uid(),reviewed_at=now(),review_note=left(p_note,1000),updated_at=now() where id=b.id;
 end if;
 if p_decision='reject' and b.payment_status='verified' then
  insert into public.refund_cases(booking_id,reason) values(b.id,left(p_note,1000)) on conflict(booking_id) do nothing;
 end if;
 insert into public.audit_logs(actor,action,subject_id,details) values(auth.uid(),'booking.'||p_decision,b.id,jsonb_build_object('note',left(p_note,1000)));
end; $$;

-- Must be called only AFTER Netlify Function verifies a signed QR token.
-- Staff identity and roles are independently checked here, even if server route gets misconfigured.
create or replace function public.check_in_ticket(p_ticket uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t public.tickets%rowtype; b public.bookings%rowtype; e public.events%rowtype; nm text;
begin
 if not public.has_role(array['owner','admin','reviewer','checkin']) then raise exception 'FORBIDDEN'; end if;
 select * into t from public.tickets where id=p_ticket for update;
 if not found then return jsonb_build_object('ok',false,'reason','NOT_FOUND'); end if;
 select * into b from public.bookings where id=t.booking_id;
 select * into e from public.events where id=t.event_id;
 select full_name into nm from public.profiles where id=b.user_id;
 if t.state='used' then
  insert into public.scan_attempts(ticket_id,staff_user_id,result) values(t.id,auth.uid(),'ALREADY_USED');
  return jsonb_build_object('ok',false,'reason','ALREADY_USED','used_at',t.used_at,'name',nm);
 end if;
 if t.state<>'active' or b.state<>'approved' or e.status='cancelled' then
  insert into public.scan_attempts(ticket_id,staff_user_id,result) values(t.id,auth.uid(),'INVALID_STATE');
  return jsonb_build_object('ok',false,'reason','INVALID_STATE');
 end if;
 if now() < e.starts_at-interval '4 hours' or now() > e.ends_at+interval '8 hours' then
  insert into public.scan_attempts(ticket_id,staff_user_id,result) values(t.id,auth.uid(),'OUTSIDE_WINDOW');
  return jsonb_build_object('ok',false,'reason','OUTSIDE_WINDOW');
 end if;
 insert into public.checkins(ticket_id,booking_id,event_id,staff_user_id) values(t.id,b.id,e.id,auth.uid());
 update public.tickets set state='used',used_at=now(),used_by=auth.uid() where id=t.id and state='active';
 insert into public.scan_attempts(ticket_id,staff_user_id,result) values(t.id,auth.uid(),'ACCEPTED');
 insert into public.audit_logs(actor,action,subject_id) values(auth.uid(),'ticket.checked_in',t.id);
 return jsonb_build_object('ok',true,'reason','ACCEPTED','name',nm,'event',e.title);
end; $$;

-- No direct writes to sensitive tables. Mutations are RPC with server-side authorization.
revoke all on function public.on_new_user() from public,anon,authenticated;
revoke all on function public.has_role(text[]) from public,anon;
grant execute on function public.has_role(text[]) to authenticated,anon;
revoke all on function public.create_booking(uuid),public.report_payment(uuid,text,text),public.verify_payment(uuid),public.decide_booking(uuid,text,text),public.check_in_ticket(uuid) from public,anon;
grant execute on function public.create_booking(uuid),public.report_payment(uuid,text,text),public.verify_payment(uuid),public.decide_booking(uuid,text,text),public.check_in_ticket(uuid) to authenticated;

create or replace function public.confirm_refund(p_case uuid) returns void
language plpgsql security definer set search_path='' as $$
declare r public.refund_cases%rowtype;
begin
 if not public.has_role(array['owner','admin']) then raise exception 'FORBIDDEN'; end if;
 select * into r from public.refund_cases where id=p_case for update;
 if not found or r.status<>'pending' then raise exception 'REFUND_CASE_NOT_PENDING'; end if;
 -- Admin must complete refund in actual provider panel FIRST; this only records its confirmation.
 update public.refund_cases set status='completed',completed_at=now(),completed_by=auth.uid() where id=r.id;
 update public.bookings set payment_status='refunded',updated_at=now() where id=r.booking_id;
 insert into public.audit_logs(actor,action,subject_id) values(auth.uid(),'payment.refund_confirmed',r.booking_id);
end; $$;
revoke all on function public.confirm_refund(uuid) from public,anon;
grant execute on function public.confirm_refund(uuid) to authenticated;

-- Owner can grant/revoke roles to EXISTING registered accounts. No exposed staff writes.
create or replace function public.set_staff_role(p_email text,p_role text,p_active boolean default true) returns void
language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
 if not public.has_role(array['owner']) then raise exception 'FORBIDDEN'; end if;
 if p_role not in ('owner','admin','reviewer','checkin') then raise exception 'INVALID_ROLE'; end if;
 select id into target from auth.users where lower(email)=lower(trim(p_email));
 if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
 if target=auth.uid() and (not p_active or p_role<>'owner') then raise exception 'CANNOT_MODIFY_OWN_OWNER_ROLE'; end if;
 insert into public.staff_members(user_id,role,active) values(target,p_role::public.staff_role,p_active)
 on conflict (user_id) do update set role=excluded.role,active=excluded.active;
 insert into public.audit_logs(actor,action,subject_id,details) values(auth.uid(),'staff.role_changed',target,jsonb_build_object('role',p_role,'active',p_active));
end; $$;
revoke all on function public.set_staff_role(text,text,boolean) from public,anon;
grant execute on function public.set_staff_role(text,text,boolean) to authenticated;

-- Important: create your first account via the site, then run ONE manual owner assignment:
-- insert into public.staff_members(user_id,role) select id,'owner' from auth.users where email='OWNER_EMAIL@example.com';
