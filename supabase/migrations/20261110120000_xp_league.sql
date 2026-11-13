-- **L'XP et la ligue de la semaine** (docs/refonte-knowunity.md, web/packages/core/src/xp.ts).
--
-- L'XP se compte sur l'appareil et monte avec le profil : le total, l'XP de la semaine et le
-- lundi de cette semaine. La ligue lit celle de l'élève et de ses amis acceptés, par une
-- fonction qui ne répond que sur l'appelant : `profiles` n'est pas lisible par les amis, et
-- ne doit pas le devenir pour trois nombres.
--
-- Une XP de semaine dont le lundi n'est pas celui de la semaine en cours compte zéro : un ami
-- qui n'a pas ouvert l'app depuis dix jours n'est pas en tête avec l'XP d'il y a dix jours.

alter table public.profiles
  add column if not exists xp_total int not null default 0,
  add column if not exists xp_week int not null default 0,
  add column if not exists xp_week_start date;

alter table public.profiles
  drop constraint if exists profiles_xp_bounds;

alter table public.profiles
  add constraint profiles_xp_bounds check (
    xp_total between 0 and 100000000
    and xp_week between 0 and 35000
  );

comment on column public.profiles.xp_week is
  'XP gagnée depuis xp_week_start (le lundi, en jour local de l''élève). Écrite par l''app.';

-- La semaine en cours, vue du serveur : le lundi UTC. Un élève très à l'est ou très à l'ouest
-- peut voir sa ligue repartir quelques heures avant ou après minuit chez lui ; c'est accepté.
create or replace function public.friends_league()
returns table (
  user_id uuid,
  username text,
  display_name text,
  xp_week int,
  is_me boolean
)
language sql
security definer
stable
set search_path = ''
as $$
  with me as (
    select (select auth.uid()) as id
  ),
  members as (
    select me.id from me where me.id is not null
    union
    select case when f.requester_id = me.id then f.addressee_id else f.requester_id end
    from public.friendships f, me
    where f.status = 'accepted'
      and (f.requester_id = me.id or f.addressee_id = me.id)
  )
  select
    p.id,
    d.username,
    p.display_name,
    case
      when p.xp_week_start >= (date_trunc('week', now() at time zone 'utc'))::date - 1
      then p.xp_week
      else 0
    end,
    p.id = (select id from me)
  from members m
  join public.profiles p on p.id = m.id
  left join public.directory d on d.id = p.id
  order by 4 desc, 2 nulls last
  limit 100;
$$;

revoke all on function public.friends_league() from public, anon;
grant execute on function public.friends_league() to authenticated;

-- **Deux appareils, une seule ligne.** L'iPhone, Android et le site écrivent chacun leurs
-- nombres ; sans garde, le dernier qui synchronise ferait redescendre l'XP gagnée sur l'autre.
-- L'XP ne redescend donc jamais : le total garde le plus grand, la semaine aussi tant que c'est
-- la même semaine. Une nouvelle semaine repart de ce que l'appareil envoie.
create or replace function public.profiles_xp_monotonic()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.xp_total := greatest(coalesce(old.xp_total, 0), coalesce(new.xp_total, 0));
  if new.xp_week_start is null then
    new.xp_week_start := old.xp_week_start;
    new.xp_week := old.xp_week;
  elsif old.xp_week_start is not null and new.xp_week_start = old.xp_week_start then
    new.xp_week := greatest(coalesce(old.xp_week, 0), coalesce(new.xp_week, 0));
  elsif old.xp_week_start is not null and new.xp_week_start < old.xp_week_start then
    -- Un appareil resté sur la semaine d'avant n'écrase pas la semaine en cours.
    new.xp_week_start := old.xp_week_start;
    new.xp_week := old.xp_week;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_xp_monotonic on public.profiles;
create trigger profiles_xp_monotonic
  before update of xp_total, xp_week, xp_week_start on public.profiles
  for each row execute function public.profiles_xp_monotonic();
