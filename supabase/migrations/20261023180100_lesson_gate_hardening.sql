-- **La porte du gratuit, refermée là où elle fuyait.** Voir `lesson_generations`,
-- `lesson_onboarding`, `lesson_extras` et `lesson_release`.
--
-- Quatre fuites, une migration :
--
-- 1. **La conversion ouvrait des thèmes.** `begin_lesson(kind = 'convert')` ne vérifiait rien
--    — ni que le cours existe, ni le nombre de chapitres — et posait `themes = p_themes`, que
--    `lesson_theme_call` lisait ensuite comme le droit d'écrire `themes * 2 + 2` thèmes. Un
--    compte gratuit déclarait donc une « conversion » de trente chapitres sous un identifiant
--    neuf, puis demandait soixante-deux thèmes, chacun écrit depuis le texte de son choix :
--    des leçons entières, sans limite, sans abonnement. Aucun client n'écrit de thème pour un
--    cours converti — l'iPhone et le site posent ses chapitres `ready` à la conversion, et
--    Android ne convertit pas —, donc `lesson_theme_call` ne sert plus qu'aux leçons créées.
-- 2. **Une ligne existante répondait `ok` à tout.** Rejouer un identifiant déjà réservé
--    rendait `ok` quel que soit le genre ou la source demandés : la leçon offerte, créée
--    depuis un sujet, se replanifiait depuis un PDF sous le même identifiant. La ligne garde
--    maintenant ce qu'elle a été ouverte pour être.
-- 3. **Deux appels simultanés passaient tous les deux.** La lecture « la leçon offerte
--    a-t-elle servi ? » et l'insertion n'étaient pas atomiques : deux plans lancés en même
--    temps, sous deux identifiants, voyaient chacun la porte ouverte. Même chose pour l'essai
--    gratuit et le plafond Pro de `begin_extra`. Un verrou consultatif par compte, pris en
--    tête de transaction, sérialise les demandes d'un même compte sans toucher aux autres.
-- 4. **Une réservation orpheline comptait pour toujours.** `release_lesson` rend la leçon
--    quand le plan échoue, mais une fonction tuée par la plateforme avant d'arriver au
--    `catch` ne rend rien. Une réservation sans plan (`themes = 0`, aucun thème servi) de
--    plus de dix minutes est donc tenue pour rendue : aucun plan ne met dix minutes.
--
-- Les comptes invités (`auth.users.is_anonymous`) gardent leur leçon offerte : l'iPhone ouvre
-- un compte invité au premier lancement, et le parcours d'accueil construit la leçon offerte
-- avec lui, avant toute inscription. Les en priver casserait la démonstration de l'app.

-- MARK: - La leçon offerte a-t-elle servi ?

-- La même règle que `begin_lesson` appliquait en ligne, sortie en fonction parce que
-- `youtube-transcript` en a besoin aussi : la lecture d'une vidéo par le modèle est la
-- première étape de la leçon offerte quand elle vient d'une vidéo, et c'est l'appel le plus
-- cher de Micabo. `p_except` écarte la leçon qu'on est en train d'ouvrir.
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
        -- Une réservation sans plan, abandonnée depuis dix minutes, ne compte pas.
        and not (g.themes = 0 and g.theme_calls = 0 and g.created_at < now() - interval '10 minutes')
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

-- Le plafond des chapitres d'une conversion : `generate-lesson` n'en lit pas plus.
-- Rend `ok`, `import_pro`, `free_limit`, `forbidden` ou `course_unknown` (une conversion
-- d'un cours que la base ne connaît pas encore, au-delà de trois par jour sans abonnement).
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

  -- Les réservations sans plan abandonnées : rendues, comme `release_lesson` l'aurait fait.
  delete from public.lesson_generations
    where user_id = p_user
      and lesson_id <> p_lesson
      and kind = 'create'
      and themes = 0
      and theme_calls = 0
      and created_at < now() - interval '10 minutes';

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

-- MARK: - Un thème

-- Faux si la leçon n'est pas à ce compte, si ce n'est pas une leçon créée (une conversion
-- n'écrit pas de thème), ou si les « Réessayer » ont dépassé deux fois le nombre de thèmes
-- (plus deux de marge).
create or replace function public.lesson_theme_call(p_user uuid, p_lesson uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed boolean;
begin
  update public.lesson_generations
    set theme_calls = theme_calls + 1
    where lesson_id = p_lesson
      and user_id = p_user
      and kind = 'create'
      and theme_calls < themes * 2 + 2
    returning true into v_allowed;
  return coalesce(v_allowed, false);
end;
$$;

revoke execute on function public.lesson_theme_call(uuid, uuid)
  from anon, authenticated, public;

-- MARK: - Les suppléments

-- Le même corps que `lesson_extras`, verrou en tête : sans lui, deux lots lancés ensemble
-- prenaient chacun l'essai gratuit, et dix examens blancs simultanés passaient le plafond Pro.
create or replace function public.begin_extra(p_user uuid, p_kind text, p_lesson uuid default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pro boolean;
  v_count int;
begin
  perform pg_advisory_xact_lock(hashtext('begin_extra'), hashtext(p_user::text));

  if p_kind not in ('practice', 'exam') then
    return 'forbidden';
  end if;

  v_pro := public.is_pro(p_user);

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
