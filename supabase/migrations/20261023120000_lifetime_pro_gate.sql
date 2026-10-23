-- Les comptes Pro à vie, reconnus aussi par le serveur.
--
-- L'app et le site ouvrent Pro aux adresses de `LIFETIME_PRO_EMAILS`
-- (`web/packages/core/src/entitlement.ts`, `LifetimePro.emails` côté Swift) sans ligne
-- `entitlements` : le compte peut ne pas encore exister, et un webhook RevenueCat peut
-- refermer une ligne offerte. Mais `is_pro` et `consume_ai_quota` ne lisaient que la table :
-- l'app laissait passer, `begin_lesson` répondait `import_pro`, et le compte retombait sur le
-- paywall à la première génération.
--
-- On ne pose donc **pas** de ligne promotionnelle — le webhook la refermerait au premier
-- événement — : la porte lit l'adresse, comme les clients. Une adresse **confirmée**
-- seulement : une inscription par mot de passe à l'adresse de quelqu'un d'autre ne doit pas
-- ouvrir Pro. `freemium-parity.test.ts` vérifie que cette liste reste celle des clients.

create or replace function public.is_lifetime_pro(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users u
    where u.id = p_user
      and u.email_confirmed_at is not null
      and lower(trim(u.email)) in (
        'adrien.not@gmail.com'
      )
  );
$$;

-- Vrai si le compte a un droit Pro valide, ou s'il est Pro à vie.
create or replace function public.is_pro(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_lifetime_pro(p_user) or exists (
    select 1 from public.entitlements e
    where e.user_id = p_user
      and e.is_pro = true
      and (e.expires_at is null or e.expires_at > now())
  );
$$;

-- Le même compteur que `20260930120000_ai_quota_pro_ceiling.sql`, à une ligne près : le
-- droit se lit par `is_pro`, pour que le plafond Pro (Mika compris) suive la même règle que
-- la porte des leçons.
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
  v_pro boolean := public.is_pro(p_user);
begin
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

revoke execute on function public.is_lifetime_pro(uuid)
  from anon, authenticated, public;
revoke execute on function public.is_pro(uuid)
  from anon, authenticated, public;
revoke execute on function public.consume_ai_quota(uuid, text, int, int, int)
  from anon, authenticated, public;
