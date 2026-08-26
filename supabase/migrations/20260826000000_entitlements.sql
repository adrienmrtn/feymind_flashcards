-- Le droit, et de quel magasin il vient.
--
-- **Un utilisateur, un droit, lisible par les deux clients.** C'est la seule chose qui empêche la
-- panne la plus coûteuse qu'on puisse livrer : un étudiant qui s'abonne sur le site et retrouve un
-- cadenas sur son téléphone.
--
-- La règle qui fait tenir tout l'édifice est ailleurs, dans le code des deux clients :
-- `app_user_id` chez RevenueCat **est** l'`auth.users.id` de Supabase, toujours. Jamais un
-- identifiant anonyme qu'on aliaserait plus tard — l'aliasing d'achats anonymes est l'endroit où
-- vivent tous les bugs de droits multiplateformes. Corollaire qu'il faut accepter : on ne vend
-- jamais avant la connexion.

create table if not exists public.entitlements (
  user_id uuid primary key references auth.users on delete cascade,
  is_pro boolean not null default false,

  product_id text,
  -- **D'où vient l'achat**, et ce n'est pas une information de curiosité : c'est elle qui décide
  -- quel magasin ouvre « Gérer mon abonnement ». Un bouton qui ouvre le mauvais donne un écran
  -- vide et un message au support.
  store text check (store is null or store in ('app_store', 'play_store', 'stripe', 'promotional')),
  period_type text check (period_type is null or period_type in ('trial', 'intro', 'normal')),

  expires_at timestamptz,
  will_renew boolean not null default false,

  -- L'événement RevenueCat qui a écrit cette ligne. Deux webhooks peuvent arriver dans le
  -- désordre : celui-ci sert à ne pas écraser un état récent avec un plus ancien.
  event_at timestamptz,
  event_id text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists entitlements_expiry_idx on public.entitlements (expires_at)
  where is_pro = true;

drop trigger if exists entitlements_touch on public.entitlements;
create trigger entitlements_touch before update on public.entitlements
  for each row execute function public.touch_updated_at();

-- MARK: - Cloisonnement
--
-- **L'utilisateur lit sa ligne, personne ne l'écrit.** C'est exactement la façon dont `directory`
-- est déjà traitée dans ce schéma : écriture par le serveur, politique de lecture pour
-- l'intéressé. Une politique d'écriture, même restreinte au propriétaire, laisserait n'importe qui
-- se déclarer abonné depuis une console de navigateur — et le paywall ne voudrait plus rien dire.

alter table public.entitlements enable row level security;

drop policy if exists "Droit : le sien" on public.entitlements;
create policy "Droit : le sien"
  on public.entitlements for select to authenticated
  using ((select auth.uid()) = user_id);

-- MARK: - L'écriture, par le webhook

-- Applique un événement RevenueCat.
--
-- `security definer` et **hors de portée des clients** : seul le webhook l'appelle, avec la clé de
-- service. Elle est écrite en fonction plutôt qu'en `upsert` direct pour une raison qui compte :
-- **elle refuse un événement plus ancien que celui déjà appliqué.** Les webhooks n'arrivent pas
-- dans l'ordre, et un « abonnement annulé » de mardi appliqué après le « renouvelé » de mercredi
-- ferme la porte à quelqu'un qui paye.
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
begin
  select e.event_at into v_known from public.entitlements e where e.user_id = p_user;

  if v_known is not null and p_event_at is not null and p_event_at < v_known then
    return query select false, (select e.is_pro from public.entitlements e where e.user_id = p_user);
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

-- MARK: - La sauvegarde d'un plan d'examen
--
-- `Exam.scheduleBackup` vit aujourd'hui dans SwiftData, et nulle part ailleurs. Conséquence : le
-- web ne peut pas **dé-planifier** un examen planifié sur l'iPhone, puisque les échéances d'avant
-- n'existent que là-bas. Or « réversible, toujours » est une promesse de l'app, et une promesse
-- qui ne vaut que sur un appareil n'est pas une promesse.
--
-- La colonne porte le même contenu que le Swift : par carte, son échéance, son intervalle et son
-- état avant que le plan ne les déplace.
alter table public.exams add column if not exists schedule_backup jsonb;

comment on column public.exams.schedule_backup is
  'Échéances des cartes avant la planification. Null quand l''examen n''est pas planifié.';

comment on table public.entitlements is
  'Le droit Pro, écrit par le webhook RevenueCat avec la clé de service. Lu par l''intéressé.';
