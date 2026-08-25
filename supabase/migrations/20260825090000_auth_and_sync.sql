-- Comptes, et stockage des cours dans le cloud.
--
-- Micabo n'avait pas de compte : tout vivait dans SwiftData, sur un seul téléphone, et
-- « Tout reste sur cet appareil » était écrit dans l'écran Profil. Cette migration installe
-- ce qu'il faut pour qu'un étudiant retrouve ses cours sur un autre appareil, et plus tard
-- sur le web.
--
-- Trois principes tiennent tout le schéma :
--
-- 1. **L'identifiant vient du client.** L'app crée un `UUID` local au moment de l'import,
--    bien avant de savoir s'il y a un compte. C'est ce même identifiant qui devient la clé
--    primaire ici : sans ça, il faudrait une table de correspondance, et deux appareils qui
--    remontent le même cours créeraient deux lignes.
-- 2. **On garde l'original ET le transformé.** `raw_text` est le document tel qu'il a été
--    lu, `sheet` est la fiche que le modèle en a écrite. Les deux, côte à côte, dans la même
--    ligne. C'est la condition de tout ce qu'on voudra faire plus tard : réécrire une fiche
--    avec un meilleur modèle, comparer deux versions, mesurer.
-- 3. **Rien ne se supprime vraiment.** `deleted_at` remplace le DELETE : un appareil hors
--    ligne depuis trois jours doit apprendre qu'un cours a disparu, et une ligne effacée ne
--    peut rien lui apprendre.

-- MARK: - Profil

-- Les réponses de l'inscription, aujourd'hui dans UserDefaults. Elles décident de la façon
-- dont le modèle écrit : elles doivent suivre l'étudiant d'un appareil à l'autre.
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  study_level text,
  country_code text not null default 'fr',
  learning_goals text[] not null default '{}',
  subjects text[] not null default '{}',
  institution_id text,
  institution_name text,
  daily_minutes int not null default 15 check (daily_minutes between 1 and 240),
  sheet_length text not null default 'standard',
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- MARK: - Cours

create table if not exists public.courses (
  -- Fourni par l'app : c'est l'identifiant SwiftData du cours.
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,

  title text not null default '',
  subject text,
  summary text not null default '',
  emoji text,
  accent_hex text,
  source text not null default 'text',
  source_file_name text,
  -- Empreinte du contenu, pour reconnaître un chapitre déjà importé. Vide sur un paquet.
  fingerprint text not null default '',

  -- LE COURS ORIGINAL, tel qu'il a été lu du document.
  raw_text text not null default '',
  -- LE COURS TRANSFORMÉ : la fiche en blocs, et sa version à plat.
  sheet jsonb,
  context_text text not null default '',

  is_from_library boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists courses_user_idx on public.courses (user_id, updated_at desc);
create index if not exists courses_fingerprint_idx on public.courses (user_id, fingerprint)
  where fingerprint <> '';

-- MARK: - Cartes

create table if not exists public.flashcards (
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  course_id uuid references public.courses on delete cascade,

  front text not null default '',
  back text not null default '',
  hint text,
  position int not null default 0,
  kind text not null default 'basic',
  choices text[] not null default '{}',
  correct_choice_index int not null default 0,
  -- Zone masquée d'une occlusion, en coordonnées relatives.
  mask_x double precision not null default 0,
  mask_y double precision not null default 0,
  mask_width double precision not null default 0,
  mask_height double precision not null default 0,
  group_id uuid,
  is_reversed boolean not null default false,
  is_suspended boolean not null default false,

  -- État de répétition espacée. Il voyage avec la carte : une révision faite sur le
  -- téléphone doit compter sur le web, sinon la carte revient deux fois.
  state text not null default 'new',
  due_date timestamptz not null default now(),
  interval_days double precision not null default 0,
  ease_factor double precision not null default 2.5,
  repetitions int not null default 0,
  lapses int not null default 0,
  step_index int not null default 0,
  last_reviewed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists flashcards_user_idx on public.flashcards (user_id, updated_at desc);
create index if not exists flashcards_course_idx on public.flashcards (course_id);
create index if not exists flashcards_due_idx on public.flashcards (user_id, due_date)
  where deleted_at is null and is_suspended = false;

-- MARK: - Historique de révision

-- Une table en ajout seul : une révision est un fait daté, elle ne se corrige pas. C'est
-- elle qui portera plus tard les statistiques et la mesure de ce qui marche.
create table if not exists public.review_logs (
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  card_id uuid references public.flashcards on delete cascade,
  reviewed_at timestamptz not null,
  rating int not null check (rating between 1 and 4),
  state_before text not null default 'new',
  previous_interval_days double precision not null default 0,
  new_interval_days double precision not null default 0,
  ease_after double precision not null default 2.5,
  created_at timestamptz not null default now()
);

create index if not exists review_logs_user_idx on public.review_logs (user_id, reviewed_at desc);
create index if not exists review_logs_card_idx on public.review_logs (card_id);

-- MARK: - Examens

create table if not exists public.exams (
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  name text not null default '',
  exam_date date not null,
  intensity text not null default 'standard',
  -- Un examen ne possède pas ses cours, il les désigne : pas de clé étrangère, sinon
  -- supprimer un cours supprimerait l'examen.
  course_ids uuid[] not null default '{}',
  is_planned boolean not null default false,
  planned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists exams_user_idx on public.exams (user_id, exam_date);

-- MARK: - Cloisonnement

-- Chaque table porte la même règle, et elle est la seule : un utilisateur ne voit et
-- n'écrit que ses lignes. `auth.uid()` est lu depuis le jeton, donc l'app n'a aucun moyen
-- de demander les cours de quelqu'un d'autre, même en trafiquant sa requête.
alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.flashcards enable row level security;
alter table public.review_logs enable row level security;
alter table public.exams enable row level security;

drop policy if exists "Profil : le sien" on public.profiles;
create policy "Profil : le sien"
  on public.profiles for all to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Cours : les siens" on public.courses;
create policy "Cours : les siens"
  on public.courses for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Cartes : les siennes" on public.flashcards;
create policy "Cartes : les siennes"
  on public.flashcards for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Historique : le sien" on public.review_logs;
create policy "Historique : le sien"
  on public.review_logs for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Examens : les siens" on public.exams;
create policy "Examens : les siens"
  on public.exams for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- MARK: - Horodatage

-- `updated_at` décide qui gagne quand deux appareils ont modifié la même ligne. Le laisser
-- au client serait lui faire confiance sur l'heure de son téléphone : il est posé ici.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists courses_touch on public.courses;
create trigger courses_touch before update on public.courses
  for each row execute function public.touch_updated_at();

drop trigger if exists flashcards_touch on public.flashcards;
create trigger flashcards_touch before update on public.flashcards
  for each row execute function public.touch_updated_at();

drop trigger if exists exams_touch on public.exams;
create trigger exams_touch before update on public.exams
  for each row execute function public.touch_updated_at();

-- MARK: - Création du profil

-- Le profil est créé par le serveur au moment de l'inscription, et pas par l'app : un
-- compte créé depuis le web, depuis un lien de connexion ou depuis un fournisseur OAuth
-- doit avoir son profil de la même façon que celui créé depuis l'iPhone.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, ''), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Une fonction du schéma `public` est exposée en RPC par PostgREST, y compris celles qui ne
-- sont là que pour un trigger. Celle-ci est `security definer` : laissée ouverte, n'importe
-- qui pourrait l'appeler avec les droits de son propriétaire. Les deux perdent donc le droit
-- d'exécution, ce qui n'empêche rien : un trigger s'exécute pour le compte du système, pas
-- pour celui de l'appelant. Le conseiller de sécurité de Supabase signale l'oubli, et c'est
-- exactement ce qu'il a signalé ici.
revoke execute on function public.handle_new_user() from anon, authenticated, public;
revoke execute on function public.touch_updated_at() from anon, authenticated, public;
