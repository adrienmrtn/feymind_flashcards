-- Durcissement : quota, facturation, index, suppression, visibilité.
--
-- Cette migration rassemble ce que les audits backend, base, paiements et
-- confidentialité ont trouvé d'actionnable sans casser les clients déjà en
-- circulation.

-- MARK: - Visibilité : privé par défaut
--
-- Le schéma disait `public`, le produit dit `private`. Un insert qui omet la
-- colonne publiait le cours aux camarades. On ne rétrograde pas les cours
-- déjà partagés : seulement le défaut des suivants.

alter table public.courses alter column visibility set default 'private';

-- MARK: - Index manquants

create index if not exists review_logs_user_state_day_idx
  on public.review_logs (user_id, state_before, reviewed_at desc);

create index if not exists friendships_requester_status_idx
  on public.friendships (requester_id, status);

create index if not exists flashcards_user_course_active_idx
  on public.flashcards (user_id, course_id)
  where deleted_at is null;

create index if not exists courses_user_library_idx
  on public.courses (user_id, is_from_library)
  where deleted_at is null;

-- MARK: - Un événement de facturation ne s'applique qu'une fois

create unique index if not exists entitlements_event_id_key
  on public.entitlements (event_id)
  where event_id is not null;

create or replace function public.apply_entitlement(
  p_user uuid,
  p_is_pro boolean,
  p_product_id text,
  p_store text,
  p_period_type text,
  p_expires_at timestamptz,
  p_will_renew boolean,
  p_event_at timestamptz,
  p_event_id text
)
returns table (applied boolean, is_pro boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_known timestamptz;
  v_known_id text;
  v_current boolean;
begin
  select e.event_at, e.event_id, e.is_pro
    into v_known, v_known_id, v_current
  from public.entitlements e
  where e.user_id = p_user;

  if p_event_id is not null and exists (
    select 1 from public.entitlements e where e.event_id = p_event_id
  ) then
    return query select false, coalesce(v_current, false);
    return;
  end if;

  -- Sans horodatage, on ne touche à rien : un événement non daté écraserait
  -- un état plus récent sans qu'on le sache.
  if p_event_at is null then
    return query select false, coalesce(v_current, false);
    return;
  end if;

  if v_known is not null and p_event_at < v_known then
    return query select false, coalesce(v_current, false);
    return;
  end if;

  if v_known is not null and p_event_at = v_known
     and v_known_id is not null and p_event_id is not null
     and p_event_id <= v_known_id then
    return query select false, coalesce(v_current, false);
    return;
  end if;

  insert into public.entitlements as e (
    user_id, is_pro, product_id, store, period_type,
    expires_at, will_renew, event_at, event_id
  ) values (
    p_user, p_is_pro, p_product_id, p_store, p_period_type,
    p_expires_at, p_will_renew, p_event_at, p_event_id
  )
  on conflict (user_id) do update set
    is_pro = excluded.is_pro,
    product_id = excluded.product_id,
    store = excluded.store,
    period_type = excluded.period_type,
    expires_at = excluded.expires_at,
    will_renew = excluded.will_renew,
    event_at = excluded.event_at,
    event_id = excluded.event_id;

  return query select true, p_is_pro;
end;
$$;

revoke execute on function public.apply_entitlement(uuid, boolean, text, text, text, timestamptz, boolean, timestamptz, text)
  from anon, authenticated, public;

-- MARK: - Quota : unités + plafond Pro

drop function if exists public.consume_ai_quota(uuid, text, int);

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
    v_ceiling := greatest(v_ceiling, 200);
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

-- MARK: - Une carte n'appartient qu'à un cours du même utilisateur

create or replace function public.enforce_flashcard_course_owner()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.course_id is not null then
    if not exists (
      select 1 from public.courses c
      where c.id = new.course_id and c.user_id = new.user_id
    ) then
      raise exception 'course_id must belong to user_id'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists flashcards_course_owner on public.flashcards;
create trigger flashcards_course_owner
  before insert or update of course_id, user_id on public.flashcards
  for each row execute function public.enforce_flashcard_course_owner();

revoke execute on function public.enforce_flashcard_course_owner()
  from anon, authenticated, public;

-- MARK: - Suppression : la liste d'attente part avec le compte

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid;
  addr text;
begin
  uid := auth.uid();
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select u.email into addr from auth.users u where u.id = uid;
  if addr is not null then
    delete from public.waitlist w where lower(w.email) = lower(addr);
  end if;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

-- MARK: - Compter les cartes sans les ramener une par une

create or replace function public.count_flashcards_by_course(p_courses uuid[])
returns table (course_id uuid, card_count int)
language sql
stable
security invoker
set search_path = ''
as $$
  select f.course_id, count(*)::int
  from public.flashcards f
  where f.course_id = any(p_courses)
    and f.deleted_at is null
  group by f.course_id;
$$;

grant execute on function public.count_flashcards_by_course(uuid[]) to authenticated;
revoke execute on function public.count_flashcards_by_course(uuid[]) from anon, public;
