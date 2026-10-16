-- La porte du gratuit, tenue par le serveur.
--
-- Sans abonnement, un compte a droit à **une** leçon écrite par l'IA, à vie, depuis un sujet
-- tapé ou un texte collé ; l'import (PDF, photo, audio, YouTube) est Pro. Voir
-- `docs/refonte-parcours.md` § 7 et § 9.4. L'app refuse avant l'appel ; mais une limite que
-- seul le client compte n'en est pas une, et aucune fonction ne vérifiait l'abonnement.
--
-- Une ligne par leçon demandée. `generate-lesson` l'écrit au plan, la relit à chaque thème
-- (un thème n'est servi que pour une leçon ouverte par ce compte, et dans la limite des
-- « Réessayer »), et la conversion d'un ancien cours y laisse la sienne sans toucher au
-- gratuit.

create table if not exists public.lesson_generations (
  -- L'identifiant de la leçon, fourni par l'app : c'est celui du cours SwiftData.
  lesson_id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  -- `create` : une leçon neuve ; `convert` : un ancien cours passé en parcours.
  kind text not null check (kind in ('create', 'convert')),
  -- D'où vient le texte : topic, text, pdf, photo, audio, youtube, docx, mixed.
  source text,
  -- Le nombre de thèmes du plan, et les appels de thème déjà servis.
  themes int not null default 0,
  theme_calls int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists lesson_generations_user_idx
  on public.lesson_generations (user_id, kind);

alter table public.lesson_generations enable row level security;

drop policy if exists "Générations : les siennes" on public.lesson_generations;
create policy "Générations : les siennes"
  on public.lesson_generations for select to authenticated
  using ((select auth.uid()) = user_id);

-- Vrai si le compte a un droit Pro valide.
create or replace function public.is_pro(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.entitlements e
    where e.user_id = p_user
      and e.is_pro = true
      and (e.expires_at is null or e.expires_at > now())
  );
$$;

-- **Ouvre une leçon**, ou dit pourquoi non.
--
-- Rend `ok`, `import_pro` (un support importé sans abonnement) ou `free_limit` (la leçon
-- offerte est déjà prise : une génération précédente, ou un cours qui n'est ni un exemple, ni
-- une reprise de la bibliothèque, ni un paquet fait à la main — « anciens cours ouverts,
-- requête consommée »). Rejouer le même `p_lesson` rend `ok` sans rien compter : une app qui
-- renvoie sa demande après une coupure ne brûle pas la leçon offerte.
create or replace function public.begin_lesson(
  p_user uuid,
  p_lesson uuid,
  p_kind text,
  p_source text,
  p_themes int
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.lesson_generations;
  v_pro boolean := public.is_pro(p_user);
  v_used boolean;
begin
  select * into v_existing from public.lesson_generations where lesson_id = p_lesson;
  if found then
    if v_existing.user_id <> p_user then
      return 'forbidden';
    end if;
    update public.lesson_generations
      set themes = greatest(themes, coalesce(p_themes, 0))
      where lesson_id = p_lesson;
    return 'ok';
  end if;

  if p_kind = 'create' and not v_pro then
    if coalesce(p_source, 'topic') not in ('topic', 'text') then
      return 'import_pro';
    end if;
    -- Un paquet de cartes fait à la main (`deck`) n'a rien coûté au modèle : il ne compte pas.
    select (
      exists (
        select 1 from public.lesson_generations g
        where g.user_id = p_user and g.kind = 'create'
      )
      or exists (
        select 1 from public.courses c
        where c.user_id = p_user
          and c.deleted_at is null
          and c.source not in ('sample', 'library', 'deck')
          and c.is_from_library = false
      )
    ) into v_used;
    if v_used then
      return 'free_limit';
    end if;
  end if;

  insert into public.lesson_generations (lesson_id, user_id, kind, source, themes)
  values (p_lesson, p_user, p_kind, p_source, greatest(0, coalesce(p_themes, 0)));
  return 'ok';
end;
$$;

-- **Compte un appel de thème.** Faux si la leçon n'est pas à ce compte, ou si les
-- « Réessayer » ont dépassé deux fois le nombre de thèmes (plus deux de marge).
create or replace function public.lesson_theme_call(p_user uuid, p_lesson uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed boolean;
begin
  update public.lesson_generations
    set theme_calls = theme_calls + 1
    where lesson_id = p_lesson
      and user_id = p_user
      and theme_calls < themes * 2 + 2
    returning true into v_allowed;
  return coalesce(v_allowed, false);
end;
$$;

revoke execute on function public.begin_lesson(uuid, uuid, text, text, int)
  from anon, authenticated, public;
revoke execute on function public.lesson_theme_call(uuid, uuid)
  from anon, authenticated, public;
revoke execute on function public.is_pro(uuid)
  from anon, authenticated, public;
