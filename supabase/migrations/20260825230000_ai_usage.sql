-- Le fusible contre la facture du modèle.
--
-- Les quatre Edge Functions acceptaient la **clé publiable** comme autorisation, répondaient à
-- `Access-Control-Allow-Origin: *`, et n'avaient aucun plafond. Sur un iPhone c'était à peu près
-- tenable : il faut extraire la clé d'un IPA, et il n'y a pas de chemin navigateur. Publiée dans
-- le paquet JavaScript d'un site, c'est une facture que n'importe qui fait monter depuis une
-- console — et le premier à s'en apercevoir serait celui qui paye.
--
-- Ce n'est **pas** le palier commercial. Le gratuit et le Pro se comptent en cours et en cartes
-- (`FreeTier`) ; ceci compte les appels au modèle, pour tout le monde, et n'existe que pour
-- qu'une boucle ne puisse pas tourner toute la nuit. Le plafond par droit arrive avec la table
-- `entitlements`, à l'étape 5.

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users on delete cascade,
  -- La journée en UTC, et pas la journée locale : un plafond qui se remet à zéro à l'heure du
  -- client se remet à zéro autant de fois qu'il y a de fuseaux.
  day date not null,
  fn text not null,
  count int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, day, fn)
);

create index if not exists ai_usage_day_idx on public.ai_usage (day desc);

-- MARK: - Cloisonnement
--
-- L'utilisateur **lit** sa consommation — c'est ce qui permettra d'écrire « il te reste N
-- générations aujourd'hui » plutôt qu'un refus sans explication — et n'écrit jamais : le
-- décompte est fait par la fonction ci-dessous, appelée par les Edge Functions avec la clé de
-- service. Un compteur qu'on peut remettre à zéro depuis le client ne compte rien.

alter table public.ai_usage enable row level security;

drop policy if exists "Usage : le sien" on public.ai_usage;
create policy "Usage : le sien"
  on public.ai_usage for select to authenticated
  using ((select auth.uid()) = user_id);

-- MARK: - Le décompte

-- Prend une unité, ou refuse.
--
-- **L'opération est atomique**, et ce n'est pas une précaution de style : deux appels lancés en
-- même temps liraient tous les deux le même compteur, et passeraient tous les deux. Le `where`
-- de la clause `on conflict` fait le test et l'incrément dans la même écriture ; quand il bloque,
-- rien n'est renvoyé, et c'est ce silence qui vaut refus.
--
-- Un refus **n'incrémente pas** : sinon un client qui insiste repousse indéfiniment sa propre
-- remise à zéro, et le compteur ne veut plus rien dire.
create or replace function public.consume_ai_quota(
  p_user uuid,
  p_fn text,
  p_ceiling int
)
returns table (allowed boolean, used int, ceiling int)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'utc')::date;
  v_count int;
begin
  insert into public.ai_usage as u (user_id, day, fn, count, updated_at)
  values (p_user, v_today, p_fn, 1, now())
  on conflict (user_id, day, fn) do update
    set count = u.count + 1, updated_at = now()
    where u.count < p_ceiling
  returning u.count into v_count;

  if v_count is null then
    select u.count into v_count
    from public.ai_usage u
    where u.user_id = p_user and u.day = v_today and u.fn = p_fn;

    return query select false, coalesce(v_count, 0), p_ceiling;
    return;
  end if;

  return query select true, v_count, p_ceiling;
end;
$$;

-- Une fonction du schéma `public` est exposée en RPC par PostgREST, y compris celle-ci. Elle est
-- `security definer` : laissée ouverte, n'importe qui pourrait décompter le quota de n'importe
-- qui, ou le sien pour rien. Seule la clé de service l'appelle, et elle passe outre.
revoke execute on function public.consume_ai_quota(uuid, text, int) from anon, authenticated, public;

comment on table public.ai_usage is
  'Appels au modèle par utilisateur, par jour et par fonction. Écrit uniquement par consume_ai_quota.';
