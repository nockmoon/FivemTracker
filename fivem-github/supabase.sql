-- FiveM Tracker : à coller dans Supabase > SQL Editor > Run
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,name text not null,role text not null default 'member' check(role in('member','lead','admin')),joined timestamptz not null default now());
create unique index if not exists profiles_name_uq on public.profiles(lower(name));
create table if not exists public.docs(coll text not null,id text not null,data jsonb not null default '{}',created_at timestamptz not null default now(),primary key(coll,id),check(pg_column_size(data)<20000));
create index if not exists docs_coll_created on public.docs(coll,created_at desc);
create table if not exists public.settings(key text primary key,value text);
alter table public.profiles enable row level security;alter table public.docs enable row level security;alter table public.settings enable row level security;

create or replace function public.my_role() returns text language sql stable security definer set search_path=public as $$select role from public.profiles where id=auth.uid()$$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare n int;inv text;nm text;
begin
 select count(*) into n from public.profiles;select value into inv from public.settings where key='invite';
 if n>0 and coalesce(inv,'')<>'' and coalesce(new.raw_user_meta_data->>'invite','')<>inv then raise exception 'Code invitation incorrect';end if;
 nm:=left(trim(coalesce(new.raw_user_meta_data->>'name','')),30);
 if length(nm)<2 then raise exception 'Pseudo invalide';end if;
 insert into public.profiles(id,name,role) values(new.id,nm,case when n=0 then 'admin' else 'member' end);
 return new;
end$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.docs_guard() returns trigger language plpgsql security definer set search_path=public as $$
declare r text:=public.my_role();u text:=auth.uid()::text;rk int;
begin
 if r is null then raise exception 'Non autorisé';end if;
 rk:=case r when 'admin' then 2 when 'lead' then 1 else 0 end;
 if tg_op='INSERT' then
  if new.coll='items' then if rk<1 then raise exception 'Non autorisé';end if;new.data:=jsonb_set(new.data,'{by}',to_jsonb(u));
  elsif new.coll in('comments','log') then new.data:=jsonb_set(new.data,'{by}',to_jsonb(u));
  elsif new.coll='notifs' then new.data:=jsonb_set(new.data,'{read}','false');
  end if;
 else
  if new.coll<>old.coll or new.id<>old.id then raise exception 'Non autorisé';end if;
  if new.coll='items' then
   if rk<1 then
    if coalesce(old.data->>'owner','')<>'' and old.data->>'owner'<>u then raise exception 'Non autorisé';end if;
    new.data:=old.data||jsonb_build_object('status',coalesce(new.data->'status',old.data->'status'),'mod',coalesce(new.data->'mod',old.data->'mod'));
   else new.data:=new.data||jsonb_build_object('by',old.data->'by');end if;
  elsif new.coll='notifs' then
   if old.data->>'to'<>u then raise exception 'Non autorisé';end if;
   new.data:=old.data||jsonb_build_object('read',coalesce((new.data->>'read')::boolean,false));
  end if;
 end if;
 return new;
end$$;
drop trigger if exists docs_guard_t on public.docs;
create trigger docs_guard_t before insert or update on public.docs for each row execute function public.docs_guard();

drop policy if exists prof_read on public.profiles;create policy prof_read on public.profiles for select to authenticated using(true);
drop policy if exists docs_read on public.docs;create policy docs_read on public.docs for select to authenticated using(coll in('items','comments','log') or(coll='notifs' and data->>'to'=auth.uid()::text));
drop policy if exists docs_ins on public.docs;create policy docs_ins on public.docs for insert to authenticated with check(coll in('items','comments','log','notifs'));
drop policy if exists docs_upd on public.docs;create policy docs_upd on public.docs for update to authenticated using(coll in('items','notifs')) with check(coll in('items','notifs'));
drop policy if exists docs_del on public.docs;create policy docs_del on public.docs for delete to authenticated using(coll='items' and public.my_role()='admin');

create or replace function public.doc_update(c text,i text,patch jsonb) returns void language plpgsql as $$
begin update public.docs set data=data||patch where coll=c and id=i;if not found then raise exception 'Introuvable ou non autorisé';end if;end$$;
create or replace function public.set_role(target uuid,new_role text) returns void language plpgsql security definer set search_path=public as $$
begin
 if public.my_role()<>'admin' then raise exception 'Non autorisé';end if;
 if target=auth.uid() then raise exception 'Vous ne pouvez pas modifier votre propre rôle';end if;
 if new_role not in('member','lead','admin') then raise exception 'Rôle invalide';end if;
 update public.profiles set role=new_role where id=target;
end$$;
revoke execute on function public.my_role(),public.doc_update(text,text,jsonb),public.set_role(uuid,text) from public,anon;
grant execute on function public.my_role(),public.doc_update(text,text,jsonb),public.set_role(uuid,text) to authenticated;

do $$ begin
 begin alter publication supabase_realtime add table public.docs;exception when others then null;end;
 begin alter publication supabase_realtime add table public.profiles;exception when others then null;end;
end$$;

-- Code d'invitation (exige ce code pour toute inscription après la tienne). Remplace la valeur puis exécute cette ligne :
-- insert into public.settings values('invite','MON-CODE-SECRET') on conflict(key) do update set value=excluded.value;
