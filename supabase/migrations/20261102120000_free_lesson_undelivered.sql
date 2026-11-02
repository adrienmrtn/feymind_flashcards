-- **Une leçon offerte prise pour un plan que personne n'a reçu.**
--
-- `20261023180100_lesson_gate_hardening` tenait pour rendue une réservation **sans plan**
-- (`themes = 0`, aucun thème servi) de plus de dix minutes. Mais `generate-lesson` pose le
-- nombre de thèmes (`begin_lesson(..., p_themes => N)`) **avant** de répondre : quand la
-- réponse se perd ensuite — le site coupe à 120 s, l'app coupe à 120 s, le réseau tombe —,
-- la ligne porte `themes = N` et compte pour toujours. L'élève n'a ni plan, ni thème, ni
-- cours, et la porte lui dit que sa leçon offerte a servi.
--
-- Une réservation de leçon créée est donc tenue pour rendue quand, au bout de dix minutes :
--
-- - **aucun thème n'a été demandé** (`theme_calls = 0`) : un client qui a reçu le plan
--   demande son premier thème aussitôt, c'est ce qui ouvre la leçon ;
-- - **et aucun cours ne porte son identifiant** (`courses.id = lesson_id`, supprimé ou non) :
--   le site écrit le cours dès le plan reçu, l'iPhone et Android le synchronisent sous le même
--   identifiant. Une ligne dans `courses`, c'est un plan arrivé quelque part.
--
-- L'ancienne règle (`themes = 0`) en est un cas particulier : aucun cours ne naît sans plan.
--
-- Rien ne s'ouvre pour autant : la ligne écartée est effacée par le `begin_lesson` suivant
-- (sous le verrou du compte), et un thème demandé ensuite sous l'ancien identifiant ne trouve
-- plus de ligne — `lesson_theme_call` le refuse. Un thème servi avant, lui, fait compter la
-- réservation (`theme_calls > 0`), et la nouvelle leçon tombe sur `free_limit`.
--
-- `create or replace` seulement : la migration se rejoue sans effet.

-- MARK: - Une réservation jamais livrée

-- Vrai quand la réservation `p_lesson` de `p_user` est une leçon créée qu'aucun client n'a
-- reçue : dix minutes, aucun thème, aucun cours. Partagée par `free_lesson_used` et par le
-- ménage de `begin_lesson`, pour que les deux ne divergent jamais d'une condition.
create or replace function public.lesson_reservation_undelivered(
  p_kind text,
  p_themes int,
  p_theme_calls int,
  p_created_at timestamptz,
  p_lesson uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_kind = 'create'
    and p_theme_calls = 0
    and p_created_at < now() - interval '10 minutes'
    and (
      p_themes = 0
      or not exists (select 1 from public.courses c where c.id = p_lesson)
    );
$$;

revoke execute on function public.lesson_reservation_undelivered(text, int, int, timestamptz, uuid)
  from anon, authenticated, public;

-- MARK: - La leçon offerte a-t-elle servi ?

create or replace function public.free_lesson_used(p_user uuid, p_except uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    exists (
      select 1 from public.lesson_generations g
      where g.user_id = p_user
        and g.kind = 'create'
        and g.lesson_id is distinct from p_except
        -- Une réservation que personne n'a reçue ne compte pas.
        and not public.lesson_reservation_undelivered(
          g.kind, g.themes, g.theme_calls, g.created_at, g.lesson_id
        )
    )
    or exists (
      -- Un paquet fait à la main (`deck`) n'a rien coûté au modèle : il ne compte pas.
      select 1 from public.courses c
      where c.user_id = p_user
        and c.id is distinct from p_except
        and c.deleted_at is null
        and c.source not in ('sample', 'library', 'deck')
        and c.is_from_library = false
    );
$$;

revoke execute on function public.free_lesson_used(uuid, uuid) from anon, authenticated, public;

-- MARK: - Ouvrir une leçon

-- Le corps de `20261023180100_lesson_gate_hardening`, à une condition près : le ménage des
-- réservations abandonnées suit `lesson_reservation_undelivered`.
create or replace function public.begin_lesson(
  p_user uuid,
  p_lesson uuid,
  p_kind text,
  p_source text,
  p_themes int,
  p_onboarding boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.lesson_generations;
  v_pro boolean;
  v_source text := coalesce(p_source, 'topic');
  v_import boolean := coalesce(p_source, 'topic') not in ('topic', 'text');
  v_onboarding boolean := coalesce(p_onboarding, false);
  v_themes int := greatest(0, coalesce(p_themes, 0));
  v_owner uuid;
  v_orphans int;
begin
  -- Une demande à la fois par compte, jusqu'à la fin de la transaction. Deux clés : l'espace
  -- des leçons, puis le compte. `begin_extra` prend le même compte dans un autre espace.
  perform pg_advisory_xact_lock(hashtext('begin_lesson'), hashtext(p_user::text));

  if p_kind not in ('create', 'convert') then
    return 'forbidden';
  end if;

  v_pro := public.is_pro(p_user);

  if p_kind = 'convert' then
    -- Aucun cours n'a trente chapitres convertis : `generate-lesson` coupe à trente.
    v_themes := least(v_themes, 30);
  else
    -- Un plan ne rend jamais plus de douze thèmes (`LIMITS.maxThemes`) : vingt, c'est la
    -- marge, et c'est surtout un plafond aux « Réessayer » qu'un appel forgé ne dépasse pas.
    v_themes := least(v_themes, 20);
  end if;

  -- Les réservations que personne n'a reçues : rendues, comme `release_lesson` l'aurait fait.
  -- Effacées, elles ne servent plus de thème non plus (`lesson_theme_call` ne les trouve pas).
  delete from public.lesson_generations g
    where g.user_id = p_user
      and g.lesson_id <> p_lesson
      and public.lesson_reservation_undelivered(
        g.kind, g.themes, g.theme_calls, g.created_at, g.lesson_id
      );

  select * into v_existing from public.lesson_generations where lesson_id = p_lesson;
  if found then
    if v_existing.user_id <> p_user then
      return 'forbidden';
    end if;
    -- Une leçon créée ne devient pas une conversion, ni l'inverse : chacune a sa porte.
    if v_existing.kind <> p_kind then
      return 'forbidden';
    end if;
    -- La source est celle pour laquelle la ligne a été ouverte. Le second appel du plan (le
    -- nombre de thèmes) renvoie la même, et passe ; une source importée qui n'y était pas
    -- est un import, et l'import est Pro. Seule exception : la leçon du parcours d'accueil,
    -- quand cette ligne est bien la seule leçon créée du compte.
    if p_kind = 'create'
       and not v_pro
       and v_import
       and v_source is distinct from coalesce(v_existing.source, 'topic')
       and not (v_onboarding and not exists (
         select 1 from public.lesson_generations g
         where g.user_id = p_user and g.kind = 'create' and g.lesson_id <> p_lesson
       ))
    then
      return 'import_pro';
    end if;
    update public.lesson_generations
      set themes = greatest(themes, v_themes),
          source = case when p_kind = 'create' then v_source else source end
      where lesson_id = p_lesson;
    return 'ok';
  end if;

  if p_kind = 'convert' then
    -- Le cours converti est celui de l'appelant. L'identifiant d'une leçon est celui de son
    -- cours : un cours d'un autre compte sous cet identifiant, c'est une demande forgée.
    select c.user_id into v_owner from public.courses c where c.id = p_lesson;
    if found and v_owner <> p_user then
      return 'forbidden';
    end if;
    -- Un cours que la base ne connaît pas encore : l'iPhone convertit à la première
    -- ouverture, et un paquet fait à la main ou une reprise de la bibliothèque n'est pas
    -- toujours monté à ce moment-là. Le refuser bloquerait l'élève devant son propre cours.
    -- Sans abonnement, trois par jour suffisent à ce cas ; au-delà, c'est une source de
    -- questions gratuites, et l'app réessaiera une fois le cours synchronisé.
    if not found and not v_pro then
      select count(*) into v_orphans
        from public.lesson_generations g
        where g.user_id = p_user
          and g.kind = 'convert'
          and g.created_at > now() - interval '1 day'
          and not exists (
            select 1 from public.courses c
            where c.id = g.lesson_id and c.user_id = p_user and c.deleted_at is null
          );
      if v_orphans >= 3 then
        return 'course_unknown';
      end if;
    end if;
  end if;

  if p_kind = 'create' and not v_pro then
    if v_import and not v_onboarding then
      return 'import_pro';
    end if;
    if public.free_lesson_used(p_user, p_lesson) then
      return 'free_limit';
    end if;
  end if;

  insert into public.lesson_generations (lesson_id, user_id, kind, source, themes)
  values (p_lesson, p_user, p_kind, p_source, v_themes);
  return 'ok';
end;
$$;

revoke execute on function public.begin_lesson(uuid, uuid, text, text, int, boolean)
  from anon, authenticated, public;
