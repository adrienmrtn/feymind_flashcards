-- Les cartes d'un cours partagé se lisent, et se recopient.
--
-- La bibliothèque ne montrait que la fiche. Les cartes existaient déjà, liées au
-- cours, mais une seule politique les tenait : « les siennes ». Un camarade
-- voyait le cours et pas le paquet.
--
-- On n'ouvre que le SELECT, et seulement pour les cartes d'un cours qu'on a
-- déjà le droit de lire. L'écriture reste au propriétaire. L'état de répétition
-- espacée voyage dans la ligne, mais celui qui reprend le cours le remet à zéro
-- à la copie : ce qu'il importe, c'est le contenu, pas ce que l'auteur savait.

drop policy if exists "Cartes : celles des cours partagés" on public.flashcards;
create policy "Cartes : celles des cours partagés"
  on public.flashcards
  for select
  to authenticated
  using (
    deleted_at is null
    and user_id <> (select auth.uid())
    and exists (
      select 1
      from public.courses c
      where c.id = flashcards.course_id
        and c.user_id = flashcards.user_id
        and c.deleted_at is null
        and (
          (
            c.visibility = 'public'
            and (
              public.share_institution((select auth.uid()), c.user_id)
              or public.are_friends((select auth.uid()), c.user_id)
            )
          )
          or (
            c.visibility = 'friends'
            and public.are_friends((select auth.uid()), c.user_id)
          )
        )
    )
  );
