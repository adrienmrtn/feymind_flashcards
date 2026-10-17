-- **Les événements de l'app Android.**
--
-- `app_events` n'acceptait que `ios` et `web` : l'app Android (`platform = 'android'`) se
-- faisait refuser chaque ligne, par la contrainte de la colonne comme par la politique
-- d'écriture. Les deux s'élargissent ; le reste (le plafond par appareil, la lecture
-- réservée à l'équipe) ne change pas.

alter table public.app_events drop constraint if exists app_events_platform_check;
alter table public.app_events
  add constraint app_events_platform_check check (platform in ('ios', 'web', 'android'));

drop policy if exists "Événements : écrire" on public.app_events;
create policy "Événements : écrire"
  on public.app_events for insert to anon, authenticated
  with check (
    platform in ('ios', 'web', 'android')
    and private.app_events_today_count(device_id) < 3000
  );
