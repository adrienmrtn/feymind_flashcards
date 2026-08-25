-- La bibliothèque, les amis, et le droit de regard sur ses propres cours.
--
-- Jusqu'ici chaque table portait la même règle, et elle était la seule : on ne voit que ses
-- lignes. C'était juste tant que Micabo était une app solitaire. Ouvrir la bibliothèque veut
-- dire ouvrir une brèche dans cette règle, et une brèche dans une règle de cloisonnement se
-- conçoit avant de s'écrire.
--
-- Quatre décisions tiennent cette migration :
--
-- 1. **La visibilité est portée par le cours, pas par le compte.** Un étudiant partage son
--    cours de SVT et garde ses notes de psychanalyse pour lui. Trois valeurs : `public`,
--    `friends`, `private`. Le défaut est `public`, parce qu'une bibliothèque vide n'intéresse
--    personne, et parce que c'est ce que l'app annonce.
-- 2. **On ne relâche que le SELECT, et jamais l'écriture.** Les politiques existantes restent
--    telles quelles : personne ne peut modifier le cours de quelqu'un d'autre. On ajoute des
--    politiques de lecture, qui s'ajoutent aux siennes sans les remplacer.
-- 3. **Les préférences d'un profil ne sortent jamais.** Un profil porte le stade d'étude, le
--    pays, les objectifs, le rythme quotidien : rien de tout ça n'a à être lu par un
--    camarade. Plutôt qu'une politique de lecture sur `profiles`, qui exposerait la ligne
--    entière — RLS filtre des lignes, pas des colonnes — une table `directory` ne porte que
--    ce qui est public : le nom d'utilisateur et l'établissement. Un déclencheur la tient à
--    jour. C'est trois colonnes dupliquées contre la certitude qu'une préférence ne peut pas
--    fuir.
-- 4. **Les cartes ne sortent pas non plus.** Reprendre un cours copie sa fiche, et l'étudiant
--    écrit ses propres cartes : c'est plus utile pour lui, et ça évite d'exposer l'état de
--    répétition espacée de quelqu'un d'autre, qui dit exactement ce qu'il sait mal.

-- MARK: - Nom d'utilisateur

-- Un nom pour se retrouver, parce qu'on ne s'ajoute pas en ami avec un UUID et qu'une adresse
-- électronique n'a pas à circuler. Il est en minuscules, sans accent, et il ne se prête pas
-- aux confusions : c'est un identifiant, pas un pseudonyme d'affichage.
alter table public.profiles
  add column if not exists username text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_username_shape'
  ) then
    alter table public.profiles
      add constraint profiles_username_shape
      check (username is null or username ~ '^[a-z0-9][a-z0-9_-]{2,19}$');
  end if;
end
$$;

-- L'unicité est insensible à la casse alors que la colonne est déjà en minuscules : c'est une
-- ceinture pour le jour où une écriture passera à côté de la normalisation.
create unique index if not exists profiles_username_key
  on public.profiles (lower(username));

-- Le nom par défaut, dérivé de ce que le fournisseur OAuth a donné.
--
-- « adrien.not@gmail.com » devient « adrien-not-4821 » : on reconnaît son compte du premier
-- coup d'œil, et le suffixe évite d'annoncer à tout l'établissement que deux Adrien se sont
-- inscrits. Sans rien d'exploitable — un prénom sans accent et quatre chiffres — la graine
-- reste dérivée de l'identité, comme demandé, sans transporter l'adresse.
create or replace function public.generate_username(seed text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  base text;
  part text;
  assembled text := '';
  candidate text;
  attempt int := 0;
begin
  base := lower(coalesce(seed, ''));
  base := translate(base, 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ', 'aaaaaaceeeeiiiinooooouuuuyyoa');
  base := regexp_replace(base, '[^a-z0-9]+', '-', 'g');
  base := regexp_replace(base, '(^-+)|(-+$)', '', 'g');

  -- Quatorze caractères, mais **coupés sur un tiret** : une troncature au milieu d'un mot se
  -- lit comme une faute de frappe. « Adrien Martinot » donnait « adrien-martino », qui a l'air
  -- d'un nom mal orthographié ; il donne « adrien », qui a l'air d'un choix.
  foreach part in array string_to_array(base, '-') loop
    exit when assembled <> '' and length(assembled) + 1 + length(part) > 14;
    assembled := case when assembled = '' then part else assembled || '-' || part end;
  end loop;

  -- Un seul mot, plus long que la limite à lui tout seul : là, il n'y a pas de tiret où
  -- couper, et on coupe donc au caractère.
  base := regexp_replace(left(assembled, 14), '-+$', '', 'g');

  if length(base) < 3 then
    base := 'etudiant';
  end if;

  loop
    candidate := base || '-' || lpad((floor(random() * 10000))::int::text, 4, '0');
    exit when not exists (
      select 1 from public.profiles where lower(username) = candidate
    );
    attempt := attempt + 1;
    -- Vingt tirages sur dix mille suffixes : au-delà, c'est que quelque chose d'autre est
    -- cassé, et rendre le dernier candidat vaut mieux que boucler pour toujours.
    exit when attempt > 20;
  end loop;

  return candidate;
end;
$$;

-- Le nom est posé à l'insertion, quelle que soit la porte d'entrée : le déclencheur
-- d'inscription, un profil créé par la synchro de l'app, ou une reprise manuelle. C'est ce
-- qui permet de rendre la colonne obligatoire sans casser un chemin d'écriture.
create or replace function public.fill_username()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.username is null then
    new.username := public.generate_username(new.display_name);
  else
    new.username := lower(new.username);
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_fill_username on public.profiles;
create trigger profiles_fill_username before insert or update of username on public.profiles
  for each row execute function public.fill_username();

update public.profiles
  set username = public.generate_username(display_name)
  where username is null;

alter table public.profiles
  alter column username set not null;

-- MARK: - Annuaire

-- Ce qu'un camarade peut lire d'un profil, et rien de plus. Voir la décision 3 en tête de
-- fichier : `profiles` reste fermé, cette table est sa vitrine.
create table if not exists public.directory (
  id uuid primary key references public.profiles on delete cascade,
  username text not null,
  institution_id text,
  institution_name text,
  updated_at timestamptz not null default now()
);

create index if not exists directory_username_idx on public.directory (lower(username));
create index if not exists directory_institution_idx on public.directory (institution_id)
  where institution_id is not null;

create or replace function public.sync_directory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.directory (id, username, institution_id, institution_name, updated_at)
  values (new.id, new.username, new.institution_id, new.institution_name, now())
  on conflict (id) do update
    set username = excluded.username,
        institution_id = excluded.institution_id,
        institution_name = excluded.institution_name,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_sync_directory on public.profiles;
create trigger profiles_sync_directory after insert or update on public.profiles
  for each row execute function public.sync_directory();

insert into public.directory (id, username, institution_id, institution_name)
  select id, username, institution_id, institution_name from public.profiles
  on conflict (id) do nothing;

-- MARK: - Amitiés

-- Une ligne par demande, et son état. Le sens compte : c'est le demandeur qui a fait le
-- premier pas, et l'écran des demandes reçues en dépend.
create table if not exists public.friendships (
  requester_id uuid not null references auth.users on delete cascade,
  addressee_id uuid not null references auth.users on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  primary key (requester_id, addressee_id),
  constraint friendships_not_self check (requester_id <> addressee_id)
);

-- Une amitié n'a pas de sens, une demande en a un. Cet index empêche donc les deux lignes
-- symétriques de coexister : sans lui, A demande B, B demande A, et les deux se retrouvent
-- avec une demande en attente alors qu'ils sont d'accord.
create unique index if not exists friendships_pair_key
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create index if not exists friendships_addressee_idx
  on public.friendships (addressee_id, status);

-- MARK: - Visibilité d'un cours

alter table public.courses
  add column if not exists visibility text not null default 'public';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'courses_visibility_values'
  ) then
    alter table public.courses
      add constraint courses_visibility_values
      check (visibility in ('public', 'friends', 'private'));
  end if;
end
$$;

-- L'index sert la bibliothèque : les cours partagés, du plus récent au plus ancien.
create index if not exists courses_shared_idx
  on public.courses (visibility, updated_at desc)
  where deleted_at is null and visibility <> 'private';

-- MARK: - Qui voit quoi

-- Deux questions, deux fonctions, et les politiques ci-dessous ne font que les appeler.
--
-- Elles sont **`security invoker`**, c'est-à-dire sans privilège particulier, et ce n'est pas
-- un détail. Une politique RLS s'évalue avec les droits de celui qui interroge : une fonction
-- `security definer` appelée depuis une politique aurait dû rester exécutable par
-- `authenticated`, et n'importe qui aurait alors pu l'appeler en RPC pour sonder le graphe des
-- amitiés de tout le monde. Sans privilège, elles ne lisent que ce que l'appelant peut déjà
-- lire — ses propres amitiés, l'annuaire — donc elles ne répondent que sur lui, et elles ne
-- peuvent rien révéler qu'une requête directe n'aurait pas révélé.
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
security invoker
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and (
        (requester_id = a and addressee_id = b)
        or (requester_id = b and addressee_id = a)
      )
  );
$$;

-- Le même établissement, et pas « aucun des deux n'en a déclaré » : deux profils sans école ne
-- sont pas camarades de classe, ils sont deux inconnus.
--
-- Elle lit l'annuaire et non `profiles`, pour la même raison que l'annuaire existe : c'est la
-- table dont l'établissement est une donnée publique.
create or replace function public.share_institution(a uuid, b uuid)
returns boolean
language sql
security invoker
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.directory da
    join public.directory db on db.id = b
    where da.id = a
      and da.institution_id is not null
      and da.institution_id = db.institution_id
  );
$$;

alter table public.directory enable row level security;
alter table public.friendships enable row level security;

-- L'annuaire est lisible par tous ceux qui ont un compte : c'est sa raison d'être, on s'ajoute
-- en ami par son nom d'utilisateur. Il n'y a pas de politique d'écriture, et c'est voulu :
-- seul le déclencheur y écrit, pour le compte du système.
drop policy if exists "Annuaire : lisible une fois connecté" on public.directory;
create policy "Annuaire : lisible une fois connecté"
  on public.directory for select to authenticated
  using (true);

-- Une demande se lit par ses deux parties, et par personne d'autre.
drop policy if exists "Amitiés : les siennes" on public.friendships;
create policy "Amitiés : les siennes"
  on public.friendships for select to authenticated
  using ((select auth.uid()) in (requester_id, addressee_id));

-- On ne demande qu'en son nom. Rien n'empêche de demander à un inconnu : c'est le destinataire
-- qui décide, et une demande refusée disparaît.
drop policy if exists "Amitiés : demander" on public.friendships;
create policy "Amitiés : demander"
  on public.friendships for insert to authenticated
  with check ((select auth.uid()) = requester_id and status = 'pending');

-- Accepter est le seul changement possible, et il n'appartient qu'au destinataire. Le
-- demandeur ne peut pas se déclarer ami de quelqu'un qui ne l'a pas dit.
drop policy if exists "Amitiés : répondre" on public.friendships;
create policy "Amitiés : répondre"
  on public.friendships for update to authenticated
  using ((select auth.uid()) = addressee_id)
  with check ((select auth.uid()) = addressee_id and status = 'accepted');

-- Refuser, annuler sa demande, se retirer d'une amitié : la même ligne s'efface, et les deux
-- côtés en ont le droit.
drop policy if exists "Amitiés : retirer" on public.friendships;
create policy "Amitiés : retirer"
  on public.friendships for delete to authenticated
  using ((select auth.uid()) in (requester_id, addressee_id));

-- La brèche, et elle est étroite. Elle ne vaut que pour la lecture, elle ne touche jamais un
-- cours supprimé, et un cours `private` n'y entre pas.
--
-- `public` se lit par les camarades du même établissement **et** par les amis : quelqu'un
-- qui a changé d'école ne perd pas l'accès aux cours de ses amis.
-- `friends` ne se lit que par les amis, quel que soit l'établissement.
drop policy if exists "Cours : ceux qu'on partage" on public.courses;
create policy "Cours : ceux qu'on partage"
  on public.courses for select to authenticated
  using (
    deleted_at is null
    and (select auth.uid()) <> user_id
    and (
      (
        visibility = 'public'
        and (
          public.share_institution((select auth.uid()), user_id)
          or public.are_friends((select auth.uid()), user_id)
        )
      )
      or (visibility = 'friends' and public.are_friends((select auth.uid()), user_id))
    )
  );

-- MARK: - Horodatage

-- L'annuaire n'est jamais mis à jour à la main : le déclencheur lui pose déjà son horodatage.
-- Celui-ci ne sert qu'à ce qu'une écriture directe, un jour, ne mente pas sur sa date.
drop trigger if exists directory_touch on public.directory;
create trigger directory_touch before update on public.directory
  for each row execute function public.touch_updated_at();

-- Le profil créé à l'inscription porte maintenant son nom d'utilisateur, et
-- `handle_new_user` n'a pas eu besoin de changer pour ça : c'est le déclencheur
-- `profiles_fill_username` qui le pose, quelle que soit la porte d'entrée.

-- Une fonction du schéma `public` est exposée en RPC par PostgREST. Celles qui ne servent
-- qu'à un déclencheur perdent le droit d'exécution : un déclencheur s'exécute pour le compte
-- du système, pas pour celui de l'appelant.
--
-- `are_friends` et `share_institution` gardent le leur, et il faut qu'elles le gardent : ce
-- sont les politiques qui les appellent, et une politique s'évalue avec les droits de celui
-- qui interroge. Elles sont sans privilège, donc les laisser ouvertes n'ouvre rien.
revoke execute on function public.fill_username() from anon, authenticated, public;
revoke execute on function public.sync_directory() from anon, authenticated, public;
revoke execute on function public.generate_username(text) from anon, authenticated, public;
