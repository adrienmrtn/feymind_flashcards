-- Un plafond Pro par fonction, pour Mika.
--
-- Le fusible Pro (2 000 appels par jour et par fonction) est fait pour qu'un usage
-- humain ne le touche jamais. Mika, lui, est un chat : chaque message est un appel, et
-- un abonné qui discute une heure en fait cinquante. Son plafond est donc un vrai
-- plafond, bas, et c'est la fonction qui le passe (`p_pro_ceiling`). Les autres
-- fonctions ne le passent pas, et gardent le fusible. Même nombre que
-- `MIKA_PRO_CEILING` dans `_shared/mika.ts`.
--
-- La signature change : l'ancienne, à quatre paramètres, est retirée. Gardée, PostgREST
-- ne saurait plus laquelle appeler quand le cinquième paramètre est omis, et c'est
-- justement ce que font toutes les fonctions sauf Mika.

drop function if exists public.consume_ai_quota(uuid, text, int, int);

create or replace function public.consume_ai_quota(
  p_user uuid,
  p_fn text,
  p_ceiling int,
  p_units int default 1,
  p_pro_ceiling int default null
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
  v_pro boolean := false;
begin
  select e.is_pro into v_pro
  from public.entitlements e
  where e.user_id = p_user
    and e.is_pro = true
    and (e.expires_at is null or e.expires_at > now());

  if coalesce(v_pro, false) then
    -- Le plafond que la fonction fixe pour ses abonnés ; à défaut, le fusible. Testé
    -- en deux branches, pas par `coalesce(greatest(1, p_pro_ceiling), …)` : `greatest`
    -- ignore les nuls et rendrait 1, ce qui plafonnerait tout abonné à un appel.
    if p_pro_ceiling is not null then
      v_ceiling := greatest(1, p_pro_ceiling);
    else
      v_ceiling := greatest(v_ceiling, 2000);
    end if;
  end if;

  insert into public.ai_usage as u (user_id, day, fn, count, updated_at)
  values (p_user, v_today, p_fn, v_units, now())
  on conflict (user_id, day, fn) do update
    set count = u.count + v_units, updated_at = now()
    where u.count + v_units <= v_ceiling
  returning u.count into v_count;

  if v_count is null then
    select u.count into v_count
    from public.ai_usage u
    where u.user_id = p_user and u.day = v_today and u.fn = p_fn;

    return query select false, coalesce(v_count, 0), v_ceiling;
    return;
  end if;

  return query select true, v_count, v_ceiling;
end;
$$;

revoke execute on function public.consume_ai_quota(uuid, text, int, int, int)
  from anon, authenticated, public;
