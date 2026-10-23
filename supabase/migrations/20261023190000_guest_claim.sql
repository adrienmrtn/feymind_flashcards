-- La réclamation des lignes d'un invité par le compte qu'il vient d'ouvrir.
--
-- Depuis le 23 octobre 2026, un invité synchronise ses leçons sous son compte anonyme
-- (`auth.users.is_anonymous`). Quand il se connecte avec Apple, Google ou un lien par
-- courriel, GoTrue ouvre (ou rouvre) un **autre** utilisateur. L'app repart alors de zéro et
-- renvoie toutes ses lignes sous ce compte - mais elles existent déjà au serveur, sous
-- l'invité : la politique « Cours : les siens » refuse la mise à jour d'une ligne qui n'est pas
-- à l'appelant, l'envoi groupé tombe en entier, à chaque passage, pour toujours.
--
-- Le compte ne peut pas prendre ces lignes lui-même (le cloisonnement l'en empêche, et c'est
-- voulu), et l'invité ne peut pas les donner (il ne connaît pas le compte avant d'y être
-- entré). D'où un jeton en deux temps :
--
--   1. **Avec la session de l'invité**, avant de passer au compte :
--        select public.create_guest_claim();          -- rend un uuid, le jeton
--   2. **Avec la session du compte**, une fois connecté :
--        select public.claim_guest(p_token => <jeton>); -- rend { "courses": 3, ... }
--
-- Le jeton prouve que l'appelant tenait la session de l'invité : sans lui, n'importe quel
-- compte pourrait réclamer n'importe quel invité dont il devinerait l'identifiant.
--
-- **Contrat (iPhone et Android appellent les mêmes deux RPC, en POST /rest/v1/rpc/…) :**
--
--   create_guest_claim() returns uuid
--     - appelant : un utilisateur **anonyme** (`is_anonymous`), sinon 42501 ;
--       sans session, 28000.
--     - efface les jetons plus anciens de cet invité, en crée un et le rend.
--     - corps de la requête : `{}`. Réponse PostgREST : la chaîne JSON de l'uuid.
--
--   claim_guest(p_token uuid) returns jsonb
--     - appelant : un utilisateur **non anonyme**, sinon 42501 ; sans session, 28000.
--     - jeton inconnu, de plus de 24 heures, ou d'un invité qui n'est plus anonyme : P0002
--       (le client oublie alors son jeton, et en redemande un s'il a encore l'invité).
--     - jeton de l'appelant lui-même : 22023.
--     - en une transaction : déplace sous l'appelant toutes les lignes de l'invité (voir la
--       liste plus bas), complète le profil de l'appelant là où il est vide, efface le jeton.
--     - rend le nombre de lignes déplacées par table, par exemple
--       `{"courses": 2, "chapters": 9, "flashcards": 41, ..., "profile": 1}`.
--     - corps de la requête : `{"p_token": "<uuid>"}`.
--
-- **Ce qui ne bouge pas.** `entitlements` : l'abonnement pris sous l'invité suit le compte par
-- RevenueCat (`logIn` puis transfert des achats), et c'est le webhook qui écrit la ligne. Les
-- amitiés et l'annuaire : un invité n'a ni nom d'utilisateur choisi ni amis. Le profil de
-- l'invité reste, vide de lignes, et part avec l'invité quand GoTrue le purge.
--
-- **Les conflits.** Les tables à identifiant client (`id uuid primary key` : cours, thèmes,
-- cartes, historique, examens, dossiers, examens blancs, leçons) ne peuvent pas en avoir :
-- un identifiant n'existe qu'une fois dans la table, sous l'invité ou sous le compte. Les
-- tables dont la clé contient l'utilisateur, si : la même journée fermée, le même
-- rendez-vous déplacé. On garde alors la ligne la plus récente. Le compteur de quota
-- (`ai_usage`), lui, s'additionne : c'est ce que les deux identités ont réellement consommé
-- ce jour-là, et garder le plus récent rendrait le quota d'un invité qui se connecte.
--
-- **L'ordre compte.** Les dossiers puis les cours avant les cartes : `flashcards_course_owner`
-- refuse une carte dont le cours n'est pas au même utilisateur, et il relit le cours au
-- moment où la carte change de propriétaire.
--
-- Idempotente : `if not exists`, `create or replace`, et des droits reposés à chaque passage.

-- MARK: - Les jetons

create table if not exists public.guest_claims (
  token uuid primary key default gen_random_uuid(),
  guest_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists guest_claims_guest_idx on public.guest_claims (guest_id);

-- Personne ne lit ni n'écrit cette table directement : seules les deux fonctions ci-dessous,
-- qui tournent avec les droits de leur propriétaire, y touchent. Le cloisonnement sans aucune
-- politique ferme la porte à `anon` comme à `authenticated`.
alter table public.guest_claims enable row level security;
revoke all on table public.guest_claims from public, anon, authenticated;

-- MARK: - Créer un jeton (session de l'invité)

create or replace function public.create_guest_claim()
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_guest uuid := auth.uid();
  v_token uuid;
begin
  if v_guest is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not exists (
    select 1 from auth.users u
    where u.id = v_guest and coalesce(u.is_anonymous, false)
  ) then
    raise exception 'only a guest can hand over its rows' using errcode = '42501';
  end if;

  -- Un seul jeton vivant par invité : celui d'une tentative précédente ne doit pas rester
  -- utilisable à côté du nouveau.
  delete from public.guest_claims where guest_id = v_guest;

  insert into public.guest_claims (guest_id)
  values (v_guest)
  returning token into v_token;

  return v_token;
end;
$$;

-- MARK: - Réclamer (session du compte)

create or replace function public.claim_guest(p_token uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_account uuid := auth.uid();
  v_guest uuid;
  v_created timestamptz;
  v_count int;
  v_result jsonb := '{}'::jsonb;
begin
  if v_account is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if exists (
    select 1 from auth.users u
    where u.id = v_account and coalesce(u.is_anonymous, false)
  ) then
    raise exception 'a guest cannot claim another guest' using errcode = '42501';
  end if;

  -- `for update` : deux appareils (ou deux passages) qui réclament le même jeton en même
  -- temps ne déplacent pas deux fois ; le second attend, puis ne trouve plus rien.
  select c.guest_id, c.created_at
    into v_guest, v_created
    from public.guest_claims c
   where c.token = p_token
   for update;

  if v_guest is null or v_created < now() - interval '24 hours' then
    raise exception 'unknown or expired claim' using errcode = 'P0002';
  end if;
  if v_guest = v_account then
    raise exception 'cannot claim oneself' using errcode = '22023';
  end if;
  -- Le jeton ne fait passer que les lignes d'un invité. Un invité devenu entre-temps un vrai
  -- compte (identité liée) garde les siennes.
  if not exists (
    select 1 from auth.users u
    where u.id = v_guest and coalesce(u.is_anonymous, false)
  ) then
    raise exception 'unknown or expired claim' using errcode = 'P0002';
  end if;

  -- Les dossiers d'abord : `courses.folder_id` les désigne.
  update public.course_folders set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('course_folders', v_count);

  update public.courses set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('courses', v_count);

  update public.chapters set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('chapters', v_count);

  -- Après les cours : `flashcards_course_owner` relit le cours de chaque carte déplacée.
  update public.flashcards set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('flashcards', v_count);

  update public.review_logs set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('review_logs', v_count);

  update public.exams set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('exams', v_count);

  update public.mock_sessions set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('mock_sessions', v_count);

  -- La leçon offerte se compte ici (`begin_lesson`) : elle suit l'élève, sinon se connecter
  -- en rouvrirait une.
  update public.lesson_generations set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('lesson_generations', v_count);

  update public.lesson_extras set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('lesson_extras', v_count);

  update public.feedback set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('feedback', v_count);

  -- Les journées fermées : clé `(user_id, day)`. La même journée des deux côtés garde la
  -- plus récente.
  update public.availability_exceptions a
     set minutes = g.minutes, created_at = g.created_at
    from public.availability_exceptions g
   where a.user_id = v_account and g.user_id = v_guest
     and g.day = a.day and g.created_at > a.created_at;
  delete from public.availability_exceptions g
   where g.user_id = v_guest
     and exists (
       select 1 from public.availability_exceptions a
       where a.user_id = v_account and a.day = g.day
     );
  update public.availability_exceptions set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('availability_exceptions', v_count);

  -- Les rendez-vous déplacés : clé `(user_id, exam_id, kind, slot)`, le plus récent gagne.
  update public.exam_plan_overrides a
     set scheduled_for = g.scheduled_for, updated_at = g.updated_at
    from public.exam_plan_overrides g
   where a.user_id = v_account and g.user_id = v_guest
     and g.exam_id = a.exam_id and g.kind = a.kind and g.slot = a.slot
     and g.updated_at > a.updated_at;
  delete from public.exam_plan_overrides g
   where g.user_id = v_guest
     and exists (
       select 1 from public.exam_plan_overrides a
       where a.user_id = v_account
         and a.exam_id = g.exam_id and a.kind = g.kind and a.slot = g.slot
     );
  update public.exam_plan_overrides set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('exam_plan_overrides', v_count);

  -- Le quota du jour : les deux identités s'additionnent (voir l'en-tête).
  update public.ai_usage a
     set count = a.count + g.count, updated_at = greatest(a.updated_at, g.updated_at)
    from public.ai_usage g
   where a.user_id = v_account and g.user_id = v_guest
     and g.day = a.day and g.fn = a.fn;
  delete from public.ai_usage g
   where g.user_id = v_guest
     and exists (
       select 1 from public.ai_usage a
       where a.user_id = v_account and a.day = g.day and a.fn = g.fn
     );
  update public.ai_usage set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('ai_usage', v_count);

  -- Les reprises et les vues de la bibliothèque : déjà comptées dans `courses`, on ne fait
  -- que changer de nom ce qui n'existe pas déjà sous le compte.
  delete from public.course_adopts g
   where g.adopter_id = v_guest
     and exists (
       select 1 from public.course_adopts a
       where a.adopter_id = v_account and a.source_course_id = g.source_course_id
     );
  update public.course_adopts set adopter_id = v_account where adopter_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('course_adopts', v_count);

  delete from public.course_views g
   where g.viewer_id = v_guest
     and exists (
       select 1 from public.course_views a
       where a.viewer_id = v_account
         and a.course_id = g.course_id and a.viewed_on = g.viewed_on
     );
  update public.course_views set viewer_id = v_account where viewer_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('course_views', v_count);

  -- Les statistiques suivent aussi : le parcours d'accueil de l'invité est celui du compte.
  update public.app_events set user_id = v_account where user_id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('app_events', v_count);

  -- Le profil : on ne remplit que ce que le compte n'a pas. Un compte qui avait déjà ses
  -- réglages (ouvert sur le site, sur un autre téléphone) les garde.
  update public.profiles p
     set display_name = coalesce(p.display_name, g.display_name),
         study_level = coalesce(p.study_level, g.study_level),
         institution_id = coalesce(p.institution_id, g.institution_id),
         institution_name = coalesce(p.institution_name, g.institution_name),
         onboarding_completed_at = coalesce(p.onboarding_completed_at, g.onboarding_completed_at),
         sheet_language = coalesce(p.sheet_language, g.sheet_language),
         tour_seen = coalesce(p.tour_seen, g.tour_seen),
         weekly_minutes = coalesce(p.weekly_minutes, g.weekly_minutes)
    from public.profiles g
   where p.id = v_account and g.id = v_guest;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('profile', v_count);

  -- Un jeton ne sert qu'une fois.
  delete from public.guest_claims where token = p_token;

  return v_result;
end;
$$;

-- MARK: - Droits

-- Exposées en RPC par PostgREST : seuls les utilisateurs connectés (invité compris, qui est
-- `authenticated`) peuvent les appeler. Chaque fonction vérifie elle-même le genre d'appelant.
revoke all on function public.create_guest_claim() from public, anon;
revoke all on function public.claim_guest(uuid) from public, anon;
grant execute on function public.create_guest_claim() to authenticated;
grant execute on function public.claim_guest(uuid) to authenticated;
