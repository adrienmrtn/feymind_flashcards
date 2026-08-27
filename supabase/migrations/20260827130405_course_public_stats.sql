-- Compteurs publics d'un cours : vues, et ajouts à la bibliothèque.
--
-- Les clients ne les écrivent pas. Un propriétaire pourrait les gonfler, et
-- une synchro qui renvoie toute la ligne les remettrait à zéro. Deux RPC
-- `security definer` les incrémentent, après avoir vérifié que l'appelant
-- a le droit de lire le cours source — les mêmes règles que
-- « Cours : ceux qu'on partage ».
--
-- Une vue compte une fois par personne et par jour. Un ajout compte une
-- fois par personne, pour le cours d'origine, jamais pour la copie.

alter table public.courses
  add column if not exists view_count bigint not null default 0,
  add column if not exists adopt_count bigint not null default 0;

create table if not exists public.course_views (
  course_id uuid not null references public.courses(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  viewed_on date not null default ((timezone('utc', now()))::date),
  primary key (course_id, viewer_id, viewed_on)
);

create table if not exists public.course_adopts (
  source_course_id uuid not null references public.courses(id) on delete cascade,
  adopter_id uuid not null references auth.users(id) on delete cascade,
  adopted_at timestamptz not null default now(),
  primary key (source_course_id, adopter_id)
);

alter table public.course_views enable row level security;
alter table public.course_adopts enable row level security;

-- Le client ne lit ni n'écrit ces tables : seuls les compteurs sur `courses`
-- sont publics, et seuls les RPC ci-dessous y touchent.

create or replace function public.can_read_shared_course(p_course_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.courses c
    where c.id = p_course_id
      and c.deleted_at is null
      and c.user_id <> p_viewer
      and (
        (
          c.visibility = 'public'
          and (
            public.share_institution(p_viewer, c.user_id)
            or public.are_friends(p_viewer, c.user_id)
          )
        )
        or (
          c.visibility = 'friends'
          and public.are_friends(p_viewer, c.user_id)
        )
      )
  );
$$;

create or replace function public.record_course_view(p_course_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  viewer uuid;
begin
  viewer := auth.uid();
  if viewer is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.can_read_shared_course(p_course_id, viewer) then
    return;
  end if;

  insert into public.course_views (course_id, viewer_id, viewed_on)
  values (p_course_id, viewer, (timezone('utc', now()))::date)
  on conflict do nothing;

  if found then
    update public.courses
      set view_count = view_count + 1
    where id = p_course_id;
  end if;
end;
$$;

create or replace function public.record_course_adopt(p_course_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  adopter uuid;
begin
  adopter := auth.uid();
  if adopter is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.can_read_shared_course(p_course_id, adopter) then
    return;
  end if;

  insert into public.course_adopts (source_course_id, adopter_id)
  values (p_course_id, adopter)
  on conflict do nothing;

  if found then
    update public.courses
      set adopt_count = adopt_count + 1
    where id = p_course_id;
  end if;
end;
$$;

-- Un upsert client ne doit jamais écraser les compteurs. Les RPC tournent
-- en definer (`postgres`), donc `current_user` n'est pas `authenticated`.
create or replace function public.protect_course_counters()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and current_user in ('authenticated', 'anon') then
    new.view_count := old.view_count;
    new.adopt_count := old.adopt_count;
  end if;
  return new;
end;
$$;

drop trigger if exists courses_protect_counters on public.courses;
create trigger courses_protect_counters
  before update on public.courses
  for each row execute function public.protect_course_counters();

revoke all on function public.can_read_shared_course(uuid, uuid) from public, anon, authenticated;
revoke all on function public.record_course_view(uuid) from public, anon;
revoke all on function public.record_course_adopt(uuid) from public, anon;
revoke all on function public.protect_course_counters() from public, anon, authenticated;

grant execute on function public.record_course_view(uuid) to authenticated;
grant execute on function public.record_course_adopt(uuid) to authenticated;

revoke all on table public.course_views from anon, authenticated, public;
revoke all on table public.course_adopts from anon, authenticated, public;
