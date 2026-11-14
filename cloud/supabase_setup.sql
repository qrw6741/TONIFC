-- Prime Football 27 · Cloud saves
-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- Accounts are a username + PIN (hashed with bcrypt). The table is locked; the game and the
-- companion app only talk to it through the functions below.

create extension if not exists pgcrypto;

create table if not exists public.pf_accounts (
  username    text primary key check (username ~ '^[a-z0-9_]{3,20}$'),
  pin_hash    text not null,
  save        jsonb,
  rev         integer not null default 0,
  device      text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- nobody can read or write the table directly (not even with the public key)
alter table public.pf_accounts enable row level security;
revoke all on public.pf_accounts from anon, authenticated;

-- create an account
create or replace function public.pf_register(p_user text, p_pin text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare u text := lower(trim(p_user));
begin
  if u !~ '^[a-z0-9_]{3,20}$' then return json_build_object('ok', false, 'error', 'Username must be 3-20 letters, numbers or _'); end if;
  if p_pin !~ '^[0-9]{4,6}$' then return json_build_object('ok', false, 'error', 'PIN must be 4-6 digits'); end if;
  if exists (select 1 from pf_accounts where username = u) then return json_build_object('ok', false, 'error', 'That username is taken'); end if;
  insert into pf_accounts(username, pin_hash) values (u, crypt(p_pin, gen_salt('bf')));
  return json_build_object('ok', true, 'rev', 0);
end $$;

-- sign in + download the save
create or replace function public.pf_load(p_user text, p_pin text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare r pf_accounts;
begin
  select * into r from pf_accounts where username = lower(trim(p_user));
  if not found or r.pin_hash <> crypt(p_pin, r.pin_hash) then return json_build_object('ok', false, 'error', 'Wrong username or PIN'); end if;
  return json_build_object('ok', true, 'save', r.save, 'rev', r.rev, 'device', r.device, 'updated_at', r.updated_at);
end $$;

-- upload the save. p_rev must match the cloud's current rev (unless p_force), so two devices can't silently overwrite each other
create or replace function public.pf_save(p_user text, p_pin text, p_save jsonb, p_rev integer, p_device text, p_force boolean default false)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare r pf_accounts;
begin
  select * into r from pf_accounts where username = lower(trim(p_user)) for update;
  if not found or r.pin_hash <> crypt(p_pin, r.pin_hash) then return json_build_object('ok', false, 'error', 'Wrong username or PIN'); end if;
  if not p_force and r.rev <> p_rev then return json_build_object('ok', false, 'error', 'conflict', 'rev', r.rev, 'device', r.device, 'updated_at', r.updated_at); end if;
  update pf_accounts set save = p_save, rev = r.rev + 1, device = p_device, updated_at = now() where username = r.username;
  return json_build_object('ok', true, 'rev', r.rev + 1);
end $$;

-- just the revision (cheap check for "is the cloud newer?")
create or replace function public.pf_rev(p_user text, p_pin text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare r pf_accounts;
begin
  select * into r from pf_accounts where username = lower(trim(p_user));
  if not found or r.pin_hash <> crypt(p_pin, r.pin_hash) then return json_build_object('ok', false, 'error', 'Wrong username or PIN'); end if;
  return json_build_object('ok', true, 'rev', r.rev, 'device', r.device, 'updated_at', r.updated_at);
end $$;

grant execute on function public.pf_register(text, text) to anon;
grant execute on function public.pf_load(text, text) to anon;
grant execute on function public.pf_save(text, text, jsonb, integer, text, boolean) to anon;
grant execute on function public.pf_rev(text, text) to anon;
