-- Des dossiers pour ranger les cours.
--
-- La bibliothèque était une liste à plat. Ça tient le premier semestre ; au troisième,
-- un étudiant a quarante cours de cinq matières, et la seule façon de retrouver le
-- chapitre 4 de thermodynamique est de faire défiler jusqu'à le voir passer. Le tri par
-- matière ne suffit pas : « Physique » n'est pas une organisation, c'est une étiquette,
-- et personne ne range son classeur en une seule pile par matière.
--
-- Un dossier porte donc un **parent**, et l'arborescence sort de là : Physique >
-- Thermodynamique > TD. C'est la structure que tout le monde connaît, et c'est la seule
-- qu'on n'a pas à expliquer.
--
-- Trois choix, et chacun évite une classe de bugs :
--
-- 1. **L'identifiant vient de l'appareil**, comme pour les cours. C'est ce qui permet à
--    l'iPhone de créer un dossier hors ligne et de le synchroniser ensuite sans qu'un
--    identifiant serveur ait à redescendre.
-- 2. **Un cours pointe vers son dossier**, pas l'inverse. Un cours est dans un dossier ou
--    dans aucun ; il n'est jamais dans deux. `on delete set null` : supprimer un dossier
--    ne supprime pas ce qu'il contenait, ça le remet à la racine. Perdre un rangement est
--    ennuyeux, perdre quarante cours ne l'est pas.
-- 3. **Un cycle est refusé en base**, pas seulement dans l'écran. Un dossier qu'on
--    déplace dans son propre descendant se retrouverait invisible des deux côtés, et
--    aucune requête récursive ne s'en sortirait.

create table if not exists public.course_folders (
  -- Fourni par l'app, comme pour les cours : c'est l'identifiant SwiftData du dossier.
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,

  -- Le dossier qui le contient. `null` = à la racine de la bibliothèque.
  parent_id uuid references public.course_folders on delete cascade,

  name text not null default '',
  -- De quoi le reconnaître d'un coup d'œil dans une liste de quinze dossiers.
  emoji text,

  -- L'ordre voulu par l'étudiant, à l'intérieur de son parent. Deux dossiers peuvent
  -- porter le même rang le temps d'une synchronisation : le nom tranche ensuite.
  position integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.courses
  add column if not exists folder_id uuid references public.course_folders on delete set null;

create index if not exists course_folders_user_parent_idx
  on public.course_folders (user_id, parent_id, position);

create index if not exists courses_folder_idx
  on public.courses (user_id, folder_id)
  where deleted_at is null;

-- MARK: - Pas de cycle

/* Le garde-fou du déplacement.
 *
 * Il remonte la chaîne des parents depuis le nouveau parent : si le dossier qu'on
 * déplace apparaît sur ce chemin, l'opération le rendrait son propre ancêtre. La borne
 * de profondeur n'est pas décorative - elle protège la fonction d'un cycle déjà présent
 * en base, qu'aucune écriture normale ne peut créer mais qu'une restauration maladroite
 * pourrait poser. */
create or replace function public.course_folder_is_ancestor(candidate uuid, folder uuid)
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  cursor_id uuid := folder;
  hops integer := 0;
begin
  if candidate is null or folder is null then
    return false;
  end if;

  while cursor_id is not null and hops < 64 loop
    if cursor_id = candidate then
      return true;
    end if;
    select parent_id into cursor_id from public.course_folders where id = cursor_id;
    hops := hops + 1;
  end loop;

  return false;
end;
$$;

create or replace function public.course_folders_no_cycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'Un dossier ne peut pas se contenir lui-même.';
    end if;
    if public.course_folder_is_ancestor(new.id, new.parent_id) then
      raise exception 'Un dossier ne peut pas être déplacé dans son propre contenu.';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists course_folders_no_cycle_trigger on public.course_folders;
create trigger course_folders_no_cycle_trigger
  before insert or update on public.course_folders
  for each row execute function public.course_folders_no_cycle();

-- MARK: - Qui voit quoi

alter table public.course_folders enable row level security;

drop policy if exists "Dossiers : les siens" on public.course_folders;
create policy "Dossiers : les siens"
  on public.course_folders for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
