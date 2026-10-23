-- **Une amitié ne change pas de partenaires.**
--
-- La politique « Amitiés : répondre » (`library_and_friends`) ne vérifiait que deux choses à
-- l'écriture : que l'appelant soit le destinataire, et que le statut devienne `accepted`. Rien
-- ne tenait `requester_id`. Le destinataire d'une demande, n'importe laquelle, pouvait donc la
-- réécrire en `{requester_id: <qui il veut>, status: accepted}` et se déclarer ami de
-- n'importe quel compte, sans que celui-ci ait rien demandé — puis lire ses cours `friends`
-- et leurs cartes (`Cours : ceux qu'on partage`, `Cartes : celles des cours partagés`).
--
-- Deux verrous, parce qu'un seul suffirait aujourd'hui et qu'aucun des deux ne coûte rien :
--
-- 1. **Les droits de colonne.** Accepter, c'est poser `status` et `responded_at`, et c'est
--    tout ce que les trois clients envoient (`SocialService.accept` sur iPhone, `Social.accept`
--    sur Android, `acceptFriend` sur le site : un PATCH de ces deux colonnes). L'API n'a donc
--    plus le droit d'écrire autre chose. Aucun client ne fait d'upsert sur cette table, qui
--    aurait demandé le droit sur toutes les colonnes.
-- 2. **Un déclencheur**, pour le jour où quelqu'un rendrait le droit d'écriture en croyant
--    bien faire : la paire et la date de la demande sont figées, pour tout le monde, la clé
--    de service comprise. Une amitié entre deux autres personnes n'est pas une mise à jour,
--    c'est une autre ligne.

create or replace function public.friendships_pin_pair()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.requester_id is distinct from old.requester_id
     or new.addressee_id is distinct from old.addressee_id then
    raise exception 'friendships: requester_id and addressee_id cannot change'
      using errcode = '42501';
  end if;
  -- La date de la demande dit qui a fait le premier pas, et quand : elle ne se réécrit pas.
  new.created_at := old.created_at;
  return new;
end;
$$;

drop trigger if exists friendships_pin_pair on public.friendships;
create trigger friendships_pin_pair
  before update on public.friendships
  for each row execute function public.friendships_pin_pair();

revoke execute on function public.friendships_pin_pair() from anon, authenticated, public;

revoke update on table public.friendships from anon, authenticated;
grant update (status, responded_at) on table public.friendships to authenticated;

-- La politique elle-même, réécrite pour dire ce qu'elle tient : on ne répond qu'à une demande
-- **en attente** qui nous est adressée. Accepter une amitié déjà acceptée ne changeait rien,
-- mais une politique qui laisse passer plus que ce qu'elle annonce finit par servir à autre
-- chose.
drop policy if exists "Amitiés : répondre" on public.friendships;
create policy "Amitiés : répondre"
  on public.friendships for update to authenticated
  using ((select auth.uid()) = addressee_id and status = 'pending')
  with check ((select auth.uid()) = addressee_id and status = 'accepted');
