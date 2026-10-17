-- **Rendre une leçon dont le plan n'a pas pu s'écrire.**
--
-- `begin_lesson` réserve la leçon (une ligne de `lesson_generations`, `themes = 0`) avant que
-- le plan ne soit demandé au modèle, puis la met à jour avec son nombre de thèmes quand le
-- plan arrive. Un plan en échec (panne du fournisseur, réponse illisible deux fois) laissait la
-- ligne en place : pour un élève sans abonnement, elle comptait comme sa leçon offerte, et
-- l'essai suivant tombait sur `free_limit` sans qu'il ait jamais rien reçu.
--
-- `generate-lesson` appelle donc `release_lesson` quand le plan échoue. Seule une réservation
-- dont le plan n'est jamais arrivé part : `themes = 0` et aucun appel de thème. Un plan déjà
-- livré (`themes > 0`), même si sa réponse s'est perdue en route, reste compté.

create or replace function public.release_lesson(p_user uuid, p_lesson uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.lesson_generations
  where lesson_id = p_lesson
    and user_id = p_user
    and kind = 'create'
    and themes = 0
    and theme_calls = 0;
$$;

revoke execute on function public.release_lesson(uuid, uuid) from anon, authenticated, public;
