-- **Un budget commun pour les appels sans compte.**
--
-- Les versions de l'app déjà installées appellent les Edge Functions avec la clé publiable,
-- sans jeton d'utilisateur (`ANON_GRACE`, `_shared/caller.ts`). Ces appels ne décomptaient
-- rien : il n'y a personne à qui attribuer une unité. Mais la clé publiable est dans chaque
-- IPA et chaque APK — quiconque la lit appelait le modèle sans plafond.
--
-- Couper ces versions d'un coup les casserait toutes, y compris celles qu'on ne peut plus
-- mettre à jour. On leur donne donc **un compteur partagé**, par fonction et par jour UTC :
-- toutes les installations anciennes réunies tiennent sous un plafond fixé par la fonction
-- (`ANON_DAILY_CEILING`). Une boucle qui le vide coupe aussi les vrais utilisateurs de ces
-- versions — c'est le prix, et c'est la raison de finir la transition.
--
-- Une table à part plutôt qu'un identifiant sentinelle dans `ai_usage` : sa colonne
-- `user_id` référence `auth.users`, et un faux compte créé pour l'occasion serait un compte
-- de plus que tout le reste du schéma devrait savoir ignorer.

create table if not exists public.ai_anon_usage (
  day date not null,
  fn text not null,
  count int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (day, fn)
);

-- Personne ne la lit ni ne l'écrit depuis l'API : seule la fonction ci-dessous y touche.
alter table public.ai_anon_usage enable row level security;
revoke all on table public.ai_anon_usage from anon, authenticated, public;

-- Prend une unité du budget commun, ou refuse. Atomique comme `consume_ai_quota` : la
-- condition est dans l'`upsert`, deux appels simultanés ne lisent pas le même compteur.
create or replace function public.consume_anon_ai_quota(
  p_fn text,
  p_ceiling int,
  p_units int default 1
)
returns table (allowed boolean, used int, ceiling int)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'utc')::date;
  v_count int;
  v_units int := greatest(1, coalesce(p_units, 1));
  v_ceiling int := greatest(1, coalesce(p_ceiling, 1));
begin
  insert into public.ai_anon_usage as u (day, fn, count, updated_at)
  values (v_today, p_fn, v_units, now())
  on conflict (day, fn) do update
    set count = u.count + v_units, updated_at = now()
    where u.count + v_units <= v_ceiling
  returning u.count into v_count;

  if v_count is null then
    select u.count into v_count
    from public.ai_anon_usage u
    where u.day = v_today and u.fn = p_fn;

    return query select false, coalesce(v_count, 0), v_ceiling;
    return;
  end if;

  -- Un premier appel au-delà du plafond (`p_units > p_ceiling`) insère quand même sa ligne :
  -- il est refusé ici, et la ligne reste au-dessus du plafond, ce qui refuse les suivants.
  if v_count > v_ceiling then
    return query select false, v_count, v_ceiling;
    return;
  end if;

  return query select true, v_count, v_ceiling;
end;
$$;

revoke execute on function public.consume_anon_ai_quota(text, int, int)
  from anon, authenticated, public;
