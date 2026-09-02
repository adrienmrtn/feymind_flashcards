-- La visite guidée du web : ce que le compte a déjà vu.
--
-- Deux colonnes, et non deux clés de `localStorage` comme le paywall et le
-- cadeau. La différence n'est pas technique : une offre revue sur un second
-- appareil est une seconde chance de vendre, une visite guidée revue est une
-- nuisance. Elle suit donc le compte, pas le navigateur.
--
-- `tour_seen` porte les pages déjà présentées, `tour_skipped` le refus global
-- (« Passer la visite »). Les réglages remettent les deux à zéro.

alter table public.profiles
  add column if not exists tour_seen text[];

alter table public.profiles
  add column if not exists tour_skipped boolean not null default false;
