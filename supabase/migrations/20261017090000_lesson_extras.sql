-- **Les suppléments d'une leçon** : de nouvelles questions d'entraînement, des examens blancs.
-- Voir docs/refonte-parcours.md § 7 (freemium) et § 13.
--
-- Sans abonnement, l'élève goûte une fois à chacun : un lot de nouvelles questions, un examen
-- blanc. Avec Micabo Pro, un plafond par jour tient le coût du modèle (40 lots, 10 examens).
-- Une ligne par supplément accordé ; `begin_extra` compte et décide, `generate-lesson`
-- l'appelle avant d'écrire quoi que ce soit.

create table if not exists public.lesson_extras (
  id bigserial primary key,
  user_id uuid not null references auth.users on delete cascade,
  kind text not null check (kind in ('practice', 'exam')),
  lesson_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists lesson_extras_user_idx
  on public.lesson_extras (user_id, kind, created_at desc);

alter table public.lesson_extras enable row level security;

drop policy if exists "Suppléments : les siens" on public.lesson_extras;
create policy "Suppléments : les siens"
  on public.lesson_extras for select to authenticated
  using ((select auth.uid()) = user_id);

-- Rend `ok`, `pro_required` (l'essai gratuit est pris), `daily_limit` (le plafond Pro du jour)
-- ou `forbidden` (un supplément inconnu).
create or replace function public.begin_extra(p_user uuid, p_kind text, p_lesson uuid default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pro boolean := public.is_pro(p_user);
  v_count int;
begin
  if p_kind not in ('practice', 'exam') then
    return 'forbidden';
  end if;

  if v_pro then
    select count(*) into v_count from public.lesson_extras
      where user_id = p_user and kind = p_kind and created_at > now() - interval '1 day';
    if v_count >= (case p_kind when 'practice' then 40 else 10 end) then
      return 'daily_limit';
    end if;
  else
    select count(*) into v_count from public.lesson_extras
      where user_id = p_user and kind = p_kind;
    if v_count >= 1 then
      return 'pro_required';
    end if;
  end if;

  insert into public.lesson_extras (user_id, kind, lesson_id) values (p_user, p_kind, p_lesson);
  return 'ok';
end;
$$;

revoke execute on function public.begin_extra(uuid, text, uuid) from anon, authenticated, public;

-- Rend le dernier supplément pris sur cette leçon quand son écriture a échoué : une panne du
-- modèle ne coûte ni l'essai gratuit, ni une part du plafond Pro. Seule une ligne de moins
-- d'un quart d'heure se rend.
create or replace function public.refund_extra(p_user uuid, p_kind text, p_lesson uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.lesson_extras
  where id = (
    select id from public.lesson_extras
    where user_id = p_user
      and kind = p_kind
      and lesson_id is not distinct from p_lesson
      and created_at > now() - interval '15 minutes'
    order by created_at desc
    limit 1
  );
$$;

revoke execute on function public.refund_extra(uuid, text, uuid) from anon, authenticated, public;
