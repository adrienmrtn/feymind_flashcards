-- Plafond Pro : un fusible, pas un palier commercial.
--
-- 200 appels/jour/fonction suffisaient à travailler, mais le refus écrivait le
-- chiffre. On le remonte assez haut pour qu'un usage humain ne le touche pas
-- (2 000), et le message côté fonction ne le cite plus. Même constante que
-- `PRO_DAILY_CEILING` dans `_shared/caller.ts`.

create or replace function public.consume_ai_quota(
  p_user uuid,
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
  v_pro boolean := false;
begin
  select e.is_pro into v_pro
  from public.entitlements e
  where e.user_id = p_user
    and e.is_pro = true
    and (e.expires_at is null or e.expires_at > now());

  if coalesce(v_pro, false) then
    v_ceiling := greatest(v_ceiling, 2000);
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

revoke execute on function public.consume_ai_quota(uuid, text, int, int)
  from anon, authenticated, public;
