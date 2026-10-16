-- **La leçon du parcours d'accueil.** Voir docs/refonte-parcours.md § 7 et § 0 (Onboarding).
--
-- Le parcours d'accueil construit le premier cours de l'élève à partir de ses supports — un
-- PDF, des photos, une vidéo —, avant toute offre : c'est la démonstration de l'app. Ce cours
-- est **la leçon offerte**. `begin_lesson` refusait tout import sans abonnement
-- (`import_pro`) ; il l'accepte maintenant quand l'app le déclare venu du parcours
-- (`p_onboarding`), et seulement si la leçon offerte n'a pas encore servi : le drapeau ne
-- donne rien de plus qu'une leçon, une fois.
--
-- La signature change : l'ancienne fonction à cinq arguments est retirée d'abord, sans quoi
-- PostgREST verrait deux candidates pour un appel à cinq paramètres nommés.

drop function if exists public.begin_lesson(uuid, uuid, text, text, int);

create or replace function public.begin_lesson(
  p_user uuid,
  p_lesson uuid,
  p_kind text,
  p_source text,
  p_themes int,
  p_onboarding boolean default false
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
    if coalesce(p_source, 'topic') not in ('topic', 'text') and not coalesce(p_onboarding, false) then
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

revoke execute on function public.begin_lesson(uuid, uuid, text, text, int, boolean)
  from anon, authenticated, public;
