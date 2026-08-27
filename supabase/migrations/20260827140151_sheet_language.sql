-- Langue des fiches, indépendante du pays de scolarisation.
--
-- Changer ce réglage n'écrit pas les fiches déjà là : il ne commande que
-- les générations suivantes. Null veut dire « celle du pays ».

alter table public.profiles
  add column if not exists sheet_language text;

alter table public.profiles
  drop constraint if exists profiles_sheet_language_check;

alter table public.profiles
  add constraint profiles_sheet_language_check
  check (
    sheet_language is null
    or sheet_language in (
      'fr', 'en', 'de', 'it', 'es', 'pt', 'cs', 'nl', 'el', 'hu', 'pl', 'ro', 'sv', 'tr'
    )
  );
