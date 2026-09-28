-- La langue d'un cours, choisie à sa création et gardée avec lui.
--
-- Jusqu'ici tout ce qui s'écrivait pour un cours — cartes, explications, blancs —
-- prenait la langue du profil au moment de l'écriture. Un cours créé en anglais
-- par un élève scolarisé en France redevenait donc français à la deuxième
-- fournée de cartes. La langue est maintenant une propriété du cours ; absente
-- sur les lignes d'avant, qui continuent de suivre le profil.

alter table public.courses
  add column if not exists language text
  check (language is null or language ~ '^[a-z]{2}$');
