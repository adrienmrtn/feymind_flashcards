-- Les événements de l'app, et rien d'autre.
--
-- Micabo ne mesurait rien. On savait combien de comptes existaient, pas combien
-- d'étudiants abandonnent le parcours d'accueil à l'écran du pays, ni combien
-- ouvrent le paywall sans jamais voir la seconde page, ni depuis quel pays. Ces
-- trois questions se répondent avec une table et une ligne par geste.
--
-- ## Ce qui n'est pas ici, et pourquoi
--
-- Pas d'adresse IP, pas d'identifiant publicitaire, pas de texte saisi. Le pays
-- vient de la région de l'appareil et de la réponse donnée au parcours, pas
-- d'une géolocalisation. `props` porte des étiquettes courtes — une étape, une
-- source d'import, un motif d'échec — jamais un contenu de cours.
--
-- ## L'appareil avant le compte
--
-- La moitié de ce qu'on veut mesurer se passe **avant** qu'il y ait un compte :
-- le parcours d'accueil se termine sur la connexion, et le paywall vient après.
-- D'où `device_id`, tiré au premier lancement et gardé ensuite : c'est lui qui
-- relie l'écran de bienvenue à l'abonnement souscrit vingt minutes plus tard.
-- `user_id` s'ajoute quand le compte arrive, et n'est jamais lu du client.

create table if not exists public.app_events (
  id uuid primary key default gen_random_uuid(),

  -- Le compte, quand il y en a un. Posé par le déclencheur depuis la session :
  -- un client qui l'enverrait lui-même se le ferait écraser.
  -- `on delete set null` et non `cascade` : une suppression de compte efface
  -- l'identité, pas le fait qu'un écran a été vu.
  user_id uuid references auth.users on delete set null,

  -- L'installation. Un tirage au premier lancement, effacé avec l'app.
  device_id uuid not null,
  -- Une ouverture de l'app, du premier plan jusqu'à l'arrière-plan.
  session_id uuid not null,

  -- Le nom de l'événement, en minuscules et souligné. La forme est contrainte
  -- parce qu'un tableau de bord qui compte `paywall_opened` et `Paywall Opened`
  -- séparément ment sans le dire.
  name text not null check (name ~ '^[a-z][a-z0-9_]{1,46}[a-z0-9]$'),

  -- Les étiquettes de l'événement. Deux mille caractères : de quoi porter une
  -- dizaine de champs courts, pas de quoi verser un cours dedans.
  props jsonb not null default '{}'::jsonb
    check (jsonb_typeof(props) = 'object' and char_length(props::text) <= 2000),

  -- La région de l'appareil (FR, DE, US…), et le pays d'études répondu au
  -- parcours. Deux colonnes et non une : un étudiant français en échange à
  -- Berlin est les deux à la fois, et les confondre fausse les deux chiffres.
  country text check (country is null or country ~ '^[A-Z]{2}$'),
  school_country text check (school_country is null or char_length(school_country) <= 16),
  locale text check (locale is null or char_length(locale) <= 16),

  platform text not null default 'ios' check (platform in ('ios', 'web')),
  app_version text check (app_version is null or char_length(app_version) <= 24),
  -- Le trafic des constructions de développement est gardé, et étiqueté : le
  -- retirer priverait d'un moyen de vérifier qu'un traceur marche, le mélanger
  -- gonflerait les chiffres de ceux qui codent l'app.
  build text not null default 'release' check (build in ('debug', 'release')),
  -- L'abonnement au moment du geste. Un paywall ouvert par un abonné n'est pas
  -- le même événement qu'un paywall ouvert par quelqu'un qui bute.
  is_pro boolean,

  -- Quand le geste a eu lieu sur l'appareil, et quand la ligne est arrivée. Les
  -- deux, parce que l'app envoie par lots et qu'un téléphone hors ligne peut
  -- remonter une heure plus tard : compter sur `received_at` daterait la soirée
  -- d'hier au lendemain matin.
  occurred_at timestamptz not null,
  received_at timestamptz not null default now()
);

-- Le tableau de bord lit par date, par nom, ou les deux. Le troisième index
-- sert le plafond ci-dessous, qui compte les lignes d'un appareil sur la
-- journée : sans lui il lirait la table entière à chaque insertion.
create index if not exists app_events_received_idx on public.app_events (received_at desc);
create index if not exists app_events_name_idx on public.app_events (name, received_at desc);
create index if not exists app_events_device_idx on public.app_events (device_id, received_at desc);
create index if not exists app_events_user_idx on public.app_events (user_id, received_at desc)
  where user_id is not null;

-- MARK: - Ce que le client ne décide pas

-- Trois choses sont posées par le serveur, et aucune n'est lue de la requête :
-- qui écrit, quand la ligne est arrivée, et dans quelle fenêtre la date de
-- l'événement a le droit de tomber.
--
-- La fenêtre existe parce qu'une horloge d'appareil se règle à la main. Sans
-- elle, un téléphone réglé en 2031 posait une ligne qui ne redescendrait
-- jamais des graphiques. On borne plutôt que de refuser : l'événement a bien eu
-- lieu, c'est sa date qui est fausse.
create or replace function public.app_events_stamp()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.user_id := (select auth.uid());
  new.received_at := now();
  new.occurred_at := least(greatest(new.occurred_at, now() - interval '30 days'), now());
  return new;
end;
$$;

revoke all on function public.app_events_stamp() from public, anon, authenticated;

drop trigger if exists app_events_stamp on public.app_events;
create trigger app_events_stamp
  before insert on public.app_events
  for each row
  execute function public.app_events_stamp();

-- MARK: - Plafond

-- Combien de lignes cet appareil a posées aujourd'hui.
--
-- La clé publique de l'app est dans le binaire : n'importe qui peut écrire dans
-- cette table. Le plafond ne l'empêche pas, il empêche d'en faire une décharge.
-- Trois mille est large — une journée d'usage intense en produit quelques
-- centaines — et c'est voulu : un plafond qui coupe un vrai utilisateur coûte
-- plus cher que les lignes qu'il aurait écrites.
--
-- **Il compte les lots précédents, pas le lot en cours** : les lignes d'un même
-- INSERT ne sont pas visibles de la fonction qui les valide. Un lot unique et
-- énorme passerait donc ; le pas suivant, non. C'est un frein sur la durée, pas
-- une garantie par ligne, et le dire vaut mieux que de le laisser croire.
--
-- **Elle vit hors de `public`, et c'est le point.** Elle doit être
-- `security definer` — sans compte il n'y a aucune politique de lecture, et un
-- `count` en politique d'insertion rendrait zéro — et elle doit être exécutable
-- par `anon`, puisqu'une politique s'évalue avec les droits de celui qui écrit.
-- Dans `public`, ces deux contraintes réunies l'auraient publiée en
-- `/rest/v1/rpc/`, où n'importe qui pourrait demander le compte du jour d'un
-- appareil. PostgREST n'expose que `public` : un schéma à part la garde
-- appelable par la politique et injoignable de l'extérieur.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create or replace function private.app_events_today_count(device uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.app_events
  where device_id = device
    and received_at >= (timezone('utc', now()))::date;
$$;

revoke all on function private.app_events_today_count(uuid) from public;
grant execute on function private.app_events_today_count(uuid) to anon, authenticated;

-- L'ancienne, publiée par erreur dans `public` le temps d'un déploiement.
drop function if exists public.app_events_today_count(uuid);

-- MARK: - Cloisonnement
--
-- Écrire : tout le monde, y compris sans compte — sinon la moitié du parcours
-- d'accueil ne se mesure pas. Lire : `team@micabo.app` seulement, sur l'adresse
-- de la session Auth et non une métadonnée que l'étudiant peut éditer.
-- Modifier et supprimer : personne. Un journal qui se réécrit ne prouve rien.

alter table public.app_events enable row level security;

drop policy if exists "Événements : écrire" on public.app_events;
create policy "Événements : écrire"
  on public.app_events for insert to anon, authenticated
  with check (
    platform in ('ios', 'web')
    and private.app_events_today_count(device_id) < 3000
  );

drop policy if exists "Événements : lire" on public.app_events;
create policy "Événements : lire"
  on public.app_events for select to authenticated
  using (lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'team@micabo.app');

revoke all on table public.app_events from public, anon, authenticated;
grant insert on table public.app_events to anon, authenticated;
grant select on table public.app_events to authenticated;

-- MARK: - Lectures

-- `security_invoker` : les vues n'ouvrent rien que la table n'ouvre déjà. Sans
-- lui, elles tourneraient avec les droits de leur propriétaire et rendraient
-- lisible à tous ce que la politique ci-dessus réserve à l'équipe.

-- Un événement par jour, par nom : la courbe de base.
create or replace view public.app_events_daily
with (security_invoker = on) as
  select
    (received_at at time zone 'utc')::date as day,
    name,
    platform,
    build,
    count(*)::int as events,
    count(distinct device_id)::int as devices,
    count(distinct user_id)::int as accounts
  from public.app_events
  group by 1, 2, 3, 4;

-- L'entonnoir du parcours d'accueil : combien d'appareils ont atteint chaque
-- écran, dans l'ordre des écrans. Le rang vient de l'app (`props->>'index'`) et
-- non d'une liste recopiée ici, qui se désynchroniserait au premier écran
-- ajouté.
create or replace view public.app_funnel_onboarding
with (security_invoker = on) as
  select
    -- Le rang passe par un filtre plutôt que par un cast direct : `'trois'::int`
    -- ferait échouer la vue entière, et une vue de tableau de bord qui tombe sur
    -- une ligne mal formée est une vue qu'on ne regarde plus.
    case
      when props ->> 'index' ~ '^[0-9]{1,3}$' then (props ->> 'index')::int
      else 999
    end as step_index,
    props ->> 'step' as step,
    count(distinct device_id)::int as devices,
    min(received_at) as first_seen,
    max(received_at) as last_seen
  from public.app_events
  where name = 'onboarding_step'
    and build = 'release'
    and props ->> 'step' is not null
  group by 1, 2;

-- Le paywall, de l'ouverture à l'achat, par porte d'entrée.
create or replace view public.app_funnel_paywall
with (security_invoker = on) as
  select
    coalesce(props ->> 'trigger', 'inconnu') as trigger,
    count(distinct device_id) filter (where name = 'paywall_opened')::int as opened,
    count(distinct device_id) filter (where name = 'paywall_plans_seen')::int as saw_plans,
    count(distinct device_id) filter (where name = 'paywall_purchase_started')::int as started,
    count(distinct device_id) filter (where name = 'paywall_purchased')::int as purchased,
    count(distinct device_id) filter (where name = 'paywall_dismissed')::int as dismissed
  from public.app_events
  where name like 'paywall\_%'
    and build = 'release'
  group by 1;

grant select on public.app_events_daily to authenticated;
grant select on public.app_funnel_onboarding to authenticated;
grant select on public.app_funnel_paywall to authenticated;
