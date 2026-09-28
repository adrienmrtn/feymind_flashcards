-- Les entonnoirs, lus depuis `app_events`, par version de l'app.
--
-- La table sait déjà tout : chaque écran du parcours d'accueil arrive avec son
-- nom et son rang (`onboarding_step`), chaque écran de la création d'un deck
-- aussi (`deck_setup_step`), et le paywall dit quand il s'ouvre, quand on passe
-- à la seconde page, quand on achète. Ce qui manquait, c'est la question posée
-- à la table : « sur cent qui ouvrent la 1.6, combien voient chaque écran, et
-- où s'arrêtent ceux qui s'arrêtent ? » Ces vues la posent une fois pour
-- toutes, et le tableau de bord n'a plus qu'à les lire.
--
-- **Par version, toujours.** Le rang d'un écran change d'une version à l'autre
-- — la 1.6 a réordonné le parcours — et un entonnoir qui mélangerait deux
-- ordres compterait deux écrans différents sous le même rang. Chaque vue se
-- partitionne par `app_version` ; on filtre dessus (`where app_version like
-- '1.6%'`) ou on la laisse comparer les versions côte à côte.
--
-- Les constructions de développement sont exclues : un développeur qui refait
-- le parcours vingt fois dans la journée n'est pas un élève.

-- ## Le parcours d'accueil : combien atteignent chaque écran

create or replace view public.onboarding_funnel as
with steps as (
  select
    app_version,
    device_id,
    props ->> 'step' as step,
    (props ->> 'index')::int as idx
  from public.app_events
  where name = 'onboarding_step'
    and build = 'release'
    and props ? 'index'
),
reached as (
  select app_version, idx, step, count(distinct device_id) as devices
  from steps
  group by 1, 2, 3
)
select
  app_version,
  idx,
  step,
  devices,
  round(100.0 * devices / nullif(first_value(devices) over w, 0), 1) as pct_of_start,
  round(100.0 * devices / nullif(lag(devices) over w, 0), 1) as pct_of_previous
from reached
window w as (partition by app_version order by idx)
order by app_version desc, idx;

comment on view public.onboarding_funnel is
  'Par version : appareils distincts ayant atteint chaque écran du parcours d''accueil, en part du premier écran et de l''écran précédent.';

-- ## Le parcours d'accueil : où s'arrêtent ceux qui s'arrêtent

create or replace view public.onboarding_dropoff as
with steps as (
  select
    app_version,
    device_id,
    props ->> 'step' as step,
    (props ->> 'index')::int as idx
  from public.app_events
  where name = 'onboarding_step'
    and build = 'release'
    and props ? 'index'
),
last_step as (
  select distinct on (app_version, device_id)
    app_version, device_id, step, idx
  from steps
  order by app_version, device_id, idx desc
),
finished as (
  select distinct device_id
  from public.app_events
  where name = 'onboarding_finished'
)
select
  l.app_version,
  l.idx,
  l.step as last_step,
  count(*) as devices,
  count(*) filter (where f.device_id is null) as stopped_here,
  round(
    100.0 * count(*) filter (where f.device_id is null)
      / nullif(sum(count(*) filter (where f.device_id is null)) over (partition by l.app_version), 0),
    1
  ) as pct_of_dropouts
from last_step l
left join finished f on f.device_id = l.device_id
group by 1, 2, 3
order by l.app_version desc, l.idx;

comment on view public.onboarding_dropoff is
  'Par version : le dernier écran vu par chaque appareil, et combien n''ont jamais fini le parcours en s''arrêtant là.';

-- ## La création d'un deck : le premier cours, et les suivants

create or replace view public.deck_setup_funnel as
with steps as (
  select
    app_version,
    device_id,
    props ->> 'step' as step,
    coalesce((props ->> 'index')::int, -2) as idx,
    coalesce((props ->> 'first')::boolean, false) as is_first
  from public.app_events
  where name = 'deck_setup_step'
    and build = 'release'
),
reached as (
  select app_version, is_first, idx, step, count(distinct device_id) as devices
  from steps
  group by 1, 2, 3, 4
),
created as (
  select app_version, count(distinct device_id) as devices
  from public.app_events
  where name = 'course_imported' and build = 'release'
  group by 1
)
select
  r.app_version,
  r.is_first,
  r.idx,
  r.step,
  r.devices,
  round(100.0 * r.devices / nullif(first_value(r.devices) over w, 0), 1) as pct_of_start,
  round(100.0 * r.devices / nullif(lag(r.devices) over w, 0), 1) as pct_of_previous,
  c.devices as devices_with_a_course
from reached r
left join created c on c.app_version = r.app_version
window w as (partition by r.app_version, r.is_first order by r.idx)
order by r.app_version desc, r.is_first desc, r.idx;

comment on view public.deck_setup_funnel is
  'Par version : appareils distincts ayant atteint chaque écran de la création d''un deck, premier cours (is_first) et suivants séparés ; l''index -1 est la page « créons ton premier cours ».';

-- ## Le paywall : ouvert, comparé, acheté

create or replace view public.paywall_funnel as
with e as (
  select app_version, device_id, name, props ->> 'trigger' as trigger
  from public.app_events
  where build = 'release'
    and name in ('paywall_opened', 'paywall_plans_seen', 'paywall_purchase_started',
                 'paywall_purchased', 'paywall_dismissed')
)
select
  app_version,
  trigger,
  count(distinct device_id) filter (where name = 'paywall_opened') as opened,
  count(distinct device_id) filter (where name = 'paywall_plans_seen') as plans_seen,
  count(distinct device_id) filter (where name = 'paywall_purchase_started') as purchase_started,
  count(distinct device_id) filter (where name = 'paywall_purchased') as purchased,
  count(distinct device_id) filter (where name = 'paywall_dismissed') as dismissed,
  round(
    100.0 * count(distinct device_id) filter (where name = 'paywall_purchased')
      / nullif(count(distinct device_id) filter (where name = 'paywall_opened'), 0),
    2
  ) as conversion_pct
from e
group by 1, 2
order by app_version desc, opened desc;

comment on view public.paywall_funnel is
  'Par version et par porte d''entrée (« inconnu » = la fin du parcours d''accueil) : appareils ayant ouvert, comparé, tenté et acheté.';

-- ## D'un bout à l'autre : installé, fini le parcours, un cours, un abonnement

create or replace view public.version_funnel as
select
  app_version,
  count(distinct device_id) filter (where name = 'app_installed') as installed,
  count(distinct device_id) filter (where name = 'onboarding_started') as onboarding_started,
  count(distinct device_id) filter (where name = 'onboarding_finished') as onboarding_finished,
  count(distinct device_id) filter (where name = 'course_imported') as first_course,
  count(distinct device_id) filter (where name = 'paywall_purchased') as subscribed
from public.app_events
where build = 'release'
group by 1
order by app_version desc;

comment on view public.version_funnel is
  'Par version : installations, parcours commencés et finis, premier cours créé, abonnements.';

-- Les vues se lisent depuis le tableau de bord avec la clé de service, jamais
-- depuis l'app : `app_events` reste en écriture seule pour les clients.
revoke all on public.onboarding_funnel, public.onboarding_dropoff,
  public.deck_setup_funnel, public.paywall_funnel, public.version_funnel
  from anon, authenticated;
