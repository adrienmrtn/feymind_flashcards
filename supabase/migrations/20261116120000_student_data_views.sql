-- Les réponses des élèves, prêtes à être lues.
--
-- `app_events` reçoit déjà tout, en vrac : une ligne par geste, les détails dans
-- `props`. Trois questions reviennent pourtant toujours — « qui sont nos élèves ? »,
-- « qu'ont-ils répondu à l'accueil ? », « quels cours importent-ils ? » — et chacune
-- demandait de déplier du JSON à la main. Ces vues le font une fois.
--
-- Ce qui n'y est pas, et n'y sera pas : le prénom (il ne quitte pas l'appareil par
-- ce canal) et le contenu des cours (seul le **nom** du cours voyage).
--
-- Les constructions de développement sont exclues, comme dans les entonnoirs.

-- ## Un élève, une ligne : toutes ses réponses d'accueil
--
-- `onboarding_profile` part à la fin du parcours avec chaque réponse. Un élève qui
-- refait le parcours en envoie un second : on garde le dernier.

create or replace view public.student_profiles
with (security_invoker = on) as
select distinct on (device_id)
  device_id,
  user_id,
  occurred_at as answered_at,
  platform,
  app_version,
  locale as device_locale,
  country as device_country,
  props ->> 'ui_language' as ui_language,
  nullif(props ->> 'gender', 'passer') as gender,
  props ->> 'country' as school_country,
  props ->> 'custom_country' as custom_country,
  props ->> 'stage' as stage,
  props ->> 'level' as level,
  props ->> 'track' as track,
  props ->> 'year' as year,
  props ->> 'exam' as exam,
  props ->> 'exam_date' as exam_date,
  -- Une valeur est coupée à 120 signes côté app : une longue liste arrive en morceaux.
  string_to_array(
    concat_ws(',', props ->> 'subjects', props ->> 'subjects_2', props ->> 'subjects_3'), ','
  ) as subjects,
  (props ->> 'subject_count')::numeric::int as subject_count,
  props ->> 'hardest_subject' as hardest_subject,
  props ->> 'goal' as goal,
  string_to_array(props ->> 'worries', ',') as worries,
  props ->> 'weekly_study' as weekly_study,
  props ->> 'study_method' as study_method,
  (props ->> 'current_score')::numeric as current_score,
  (props ->> 'target_score')::numeric as target_score,
  (props ->> 'daily_minutes')::numeric::int as daily_minutes,
  (props ->> 'study_hour')::numeric::int as study_hour,
  props ->> 'institution' as institution,
  props ->> 'first_lesson' as first_lesson,
  (props ->> 'committed')::boolean as committed,
  (props ->> 'has_account')::boolean as has_account,
  (props ->> 'skipped_averages')::boolean as skipped_averages,
  is_pro
from public.app_events
where name = 'onboarding_profile'
  and build = 'release'
order by device_id, occurred_at desc;

comment on view public.student_profiles is
  'Un élève par ligne : ses réponses au parcours d''accueil (langue, genre, pays, classe, matières, objectif…). Jamais le prénom.';

-- ## Chaque réponse, au moment où elle est donnée
--
-- `student_profiles` ne connaît que ceux qui finissent. Ceux qui s'arrêtent en route
-- ont quand même répondu à quelque chose : c'est ici.

create or replace view public.onboarding_answers
with (security_invoker = on) as
select
  occurred_at,
  device_id,
  user_id,
  platform,
  app_version,
  locale as device_locale,
  props ->> 'field' as field,
  concat_ws(',', props ->> 'value', props ->> 'value_2', props ->> 'value_3') as value
from public.app_events
where name = 'onboarding_answer'
  and build = 'release';

comment on view public.onboarding_answers is
  'Une ligne par réponse donnée pendant le parcours d''accueil, y compris par ceux qui ne le finissent pas.';

-- ## Les cours importés : leur nom, jamais leur contenu

create or replace view public.imported_courses
with (security_invoker = on) as
select
  occurred_at,
  device_id,
  user_id,
  platform,
  app_version,
  props ->> 'title' as title,
  props ->> 'subject' as subject,
  props ->> 'source' as source,
  props ->> 'language' as language,
  (props ->> 'cards')::numeric::int as cards,
  (props ->> 'chars')::numeric::int as chars,
  coalesce((props ->> 'generated')::boolean, false) as generated,
  is_pro
from public.app_events
where name = 'course_imported'
  and build = 'release';

comment on view public.imported_courses is
  'Une ligne par cours créé ou importé : son nom, sa matière, sa source, sa taille. Jamais son contenu.';

-- ## La langue de l'app, par appareil : la dernière connue

create or replace view public.device_languages
with (security_invoker = on) as
select distinct on (device_id)
  device_id,
  user_id,
  platform,
  props ->> 'ui_language' as ui_language,
  locale as device_locale,
  country as device_country,
  occurred_at as seen_at
from public.app_events
where name = 'app_opened'
  and props ? 'ui_language'
  and build = 'release'
order by device_id, occurred_at desc;

comment on view public.device_languages is
  'Par appareil : la langue choisie dans l''app à sa dernière ouverture, à côté de celle du téléphone.';

-- Lues avec la clé de service ou par l'équipe, jamais depuis l'app.
revoke all on public.student_profiles, public.onboarding_answers,
  public.imported_courses, public.device_languages
  from anon, authenticated;
