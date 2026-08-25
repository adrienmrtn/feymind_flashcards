-- La liste d'attente du site.
--
-- Le site existe avant l'app : il n'y a ni parcours d'accueil, ni encaissement, ni version
-- publiée sur l'App Store. Une page d'accueil sans appel à l'action est une page d'accueil
-- qu'on lit et qu'on quitte, et un bouton qui ne fait rien est pire que pas de bouton.
-- Cette table est donc la seule chose que la page d'accueil sait faire, et elle le fait
-- vraiment.
--
-- Elle disparaîtra le jour où le parcours d'accueil prend sa place — mais pas ses lignes :
-- ce sont des gens à prévenir.

create table if not exists public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  -- Le pays et le stade d'étude, s'ils ont été donnés. Facultatifs, parce qu'un formulaire
  -- de liste d'attente qui demande trois choses n'en reçoit aucune.
  country_code text,
  study_level text,
  -- D'où vient l'inscription : la section de la page, ou la campagne. Écrit par le site.
  source text not null default 'landing',
  created_at timestamptz not null default now()
);

-- Une adresse ne s'inscrit qu'une fois, et la casse ne compte pas : « A@b.fr » et « a@b.fr »
-- sont la même personne, et lui écrire deux fois est le meilleur moyen d'être signalé comme
-- indésirable.
create unique index if not exists waitlist_email_key on public.waitlist (lower(email));

create index if not exists waitlist_created_idx on public.waitlist (created_at desc);

-- MARK: - Cloisonnement
--
-- Le cas est l'inverse de tout le reste du schéma : ici on **écrit sans être connecté**, et
-- on ne lit jamais. Une politique de lecture, même restreinte, exposerait la liste des
-- adresses de tous les inscrits à n'importe quel visiteur — c'est exactement le genre de
-- fuite qu'on lit dans la presse. Il n'y a donc aucune politique de `select` : la liste ne
-- se consulte que depuis le tableau de bord, avec la clé de service.

alter table public.waitlist enable row level security;

drop policy if exists "Liste d'attente : s'inscrire" on public.waitlist;
create policy "Liste d'attente : s'inscrire"
  on public.waitlist for insert to anon, authenticated
  with check (
    -- La forme est vérifiée ici et pas seulement dans le formulaire : une politique
    -- s'applique toujours, une validation côté client se contourne avec une console.
    email ~ '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'
    and length(email) between 6 and 254
    and source in ('landing', 'hero', 'pricing', 'questions')
  );

-- Rien d'autre. Pas de `select`, pas d'`update`, pas de `delete` : une inscription est un
-- fait daté, et personne n'a besoin de relire la liste depuis le site.

comment on table public.waitlist is
  'Les adresses laissées sur le site avant l''ouverture. Insertion anonyme, lecture réservée à la clé de service.';
