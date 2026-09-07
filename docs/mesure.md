# Savoir ce qui se passe sur micabo.app

Quatre tableaux de bord existent déjà autour du produit — Vercel, Supabase, RevenueCat,
Stripe — et **chacun ne répond qu'à une question**. Le piège est de les ouvrir en espérant
que l'un d'eux dise tout : Stripe ne sait pas combien de gens sont venus, Vercel ne sait pas
combien de comptes ont été créés, et RevenueCat ne sait rien de qui n'a pas payé.

Ce document dit qui répond à quoi, donne les requêtes prêtes à coller, et nomme ce que
personne ne mesure aujourd'hui.

---

## La carte, en une page

| La question | L'outil | Où |
|---|---|---|
| Combien de gens sont venus sur le site ? | **Vercel Web Analytics** | Vercel → projet → Analytics |
| D'où viennent-ils (Google, TikTok, un lien) ? | **Vercel Web Analytics** | onglet Referrers |
| Sur quel écran d'accueil décrochent-ils ? | **Vercel Web Analytics** | Top Paths, lignes `/commencer/*` |
| Combien de comptes créés ? | **Supabase** | requête `auth.users` ci-dessous |
| Combien terminent l'accueil ? | **Supabase** | `profiles.onboarding_completed_at` |
| Combien reviennent réviser ? | **Supabase** | `review_logs` |
| Combien d'abonnés, d'essais, de résiliations ? | **RevenueCat** | Charts |
| Combien d'argent, quels échecs de paiement ? | **Stripe** | Dashboard → Payments |
| Combien de téléchargements sur l'App Store ? | **App Store Connect** | App Analytics |
| Sur quel écran d'accueil **iPhone** décroche-t-on ? | *personne* | voir « Les angles morts » |

Aucun de ces outils ne remplace un autre. En revanche, trois suffisent au quotidien :
**Vercel pour l'avant-compte, Supabase pour l'usage, RevenueCat pour l'argent.**

---

## 1. Vercel — les visites, et l'entonnoir d'accueil gratuit

Le composant `<Analytics />` est monté dans `web/app/layout.tsx`. Il reste à **l'activer côté
Vercel** : projet → onglet Analytics → *Enable*. Sans ce clic, le script est servi et les
événements sont jetés.

### Ce que ça donne

Visiteurs uniques, pages vues, pages les plus vues, provenance, pays, navigateur, appareil.
Pas de session, pas de chemin individuel, pas d'entonnoir tout fait.

### Le tour de passe-passe qui rend l'entonnoir lisible

Le parcours d'accueil du site est **treize adresses distinctes** — `/commencer/bienvenue`,
`/commencer/importer`, … `/commencer/compte` (`web/lib/onboarding/steps.ts`). La colonne
« Top Paths » de Vercel les liste donc séparément, dans l'ordre où on les traverse, avec un
nombre chacune. **L'entonnoir se lit directement dans ce tableau, sans écrire un seul
événement** : la marche où le nombre s'effondre est l'écran qui perd les gens.

C'est la raison principale de brancher Vercel plutôt qu'autre chose : le travail
d'instrumentation a déjà été fait par le routage.

Deux précautions de lecture :

- Le nombre de `/commencer/bienvenue` compte les *arrivées*, pas les personnes : un retour en
  arrière recompte. Les écarts entre marches successives restent justes, le total non.
- Les aperçus (`micabo-git-…`) ne polluent rien : le middleware les redirige vers le site
  avant le rendu (`web/middleware.ts`).

### Ce que ça coûte

| | Hobby | Pro |
|---|---|---|
| Événements inclus | 50 000 / mois | à l'usage, 3 $ / 100 000 |
| Fenêtre d'historique | 1 mois | 12 mois |
| Événements personnalisés (`track()`) | non | oui |

Un événement = une page vue. Un parcours d'accueil complet en consomme une quinzaine. Sur le
plan Hobby, **la collecte se met en pause** une fois les 50 000 atteints (trois jours de
grâce), elle ne se facture pas. La fenêtre d'un mois est la vraie limite : elle interdit de
comparer septembre à juin.

`track()` — les événements personnalisés, qui permettraient de marquer « a cliqué sur
S'abonner » — demande le plan Pro. Tant qu'on est sur Hobby, il ne sert à rien de l'appeler :
ce serait du code mort.

### Speed Insights, à ne pas confondre

C'est le même menu Vercel, mais ça mesure la vitesse (LCP, CLS), pas l'audience. Utile, hors
sujet ici, et facturé à part (10 $/mois par projet sur Pro).

---

## 2. Supabase — les comptes, l'accueil, l'usage réel

C'est la seule source qui sache ce que fait quelqu'un **après** avoir un compte. Tout se lit
dans le SQL editor du tableau de bord, qui tourne avec la clé de service : le cloisonnement
(RLS) ne s'y applique pas, et `auth.users` est lisible — ce n'est le cas d'aucun client de
l'app.

Le tableau de bord Supabase a aussi des rapports tout faits (Reports → Auth) : inscriptions
et utilisateurs actifs par jour, sans écrire de SQL. Ils suffisent pour le coup d'œil du
matin ; les requêtes ci-dessous servent quand on veut un taux plutôt qu'une courbe.

### Comptes créés par jour

```sql
select
  (created_at at time zone 'Europe/Paris')::date as jour,
  count(*) as comptes
from auth.users
where created_at > now() - interval '30 days'
group by 1
order by 1 desc;
```

### Accueil terminé

```sql
select
  count(*) as comptes,
  count(onboarding_completed_at) as accueil_termine,
  round(100.0 * count(onboarding_completed_at) / nullif(count(*), 0), 1) as taux
from public.profiles
where created_at > now() - interval '30 days';
```

**À lire avec la bonne définition.** Sur le site, le compte se crée à la *dernière* marche du
parcours : `onboarding_completed_at` est écrit dans la foulée de l'inscription, donc ce taux
mesure la synchronisation, pas l'abandon. L'abandon d'accueil du site se lit chez Vercel
(section 1) ; ce taux-ci sert surtout à repérer une panne d'écriture du profil.

### Activation : ont-ils importé, ont-ils révisé ?

Un compte qui n'importe rien n'existe pas. La fenêtre est de sept jours, sur les inscrits
d'il y a plus d'une semaine — sinon on compte comme perdus des gens qui n'ont pas encore eu
le temps.

```sql
with nouveaux as (
  select id, created_at
  from public.profiles
  where created_at between now() - interval '37 days' and now() - interval '7 days'
)
select
  count(*) as comptes,
  count(*) filter (
    where exists (
      select 1 from public.courses c
      where c.user_id = n.id
        and c.deleted_at is null
        and c.created_at < n.created_at + interval '7 days'
    )
  ) as ont_importe,
  count(*) filter (
    where exists (
      select 1 from public.review_logs r
      where r.user_id = n.id
        and r.reviewed_at < n.created_at + interval '7 days'
    )
  ) as ont_revise
from nouveaux n;
```

### Qui revient réviser

```sql
select
  (reviewed_at at time zone 'Europe/Paris')::date as jour,
  count(distinct user_id) as reviseurs,
  count(*) as revisions
from public.review_logs
where reviewed_at > now() - interval '30 days'
group by 1
order by 1 desc;
```

### Rétention par cohorte d'inscription

La question qui décide de tout le reste : sur les gens inscrits une semaine donnée, combien
révisent encore une, deux, trois semaines plus tard.

```sql
with cohortes as (
  select id, date_trunc('week', created_at) as semaine_0
  from public.profiles
  where created_at > now() - interval '12 weeks'
),
activite as (
  select distinct user_id, date_trunc('week', reviewed_at) as semaine
  from public.review_logs
)
select
  cohortes.semaine_0::date as cohorte,
  count(distinct cohortes.id) as inscrits,
  count(distinct activite.user_id) filter (
    where activite.semaine = cohortes.semaine_0 + interval '1 week') as semaine_1,
  count(distinct activite.user_id) filter (
    where activite.semaine = cohortes.semaine_0 + interval '2 weeks') as semaine_2,
  count(distinct activite.user_id) filter (
    where activite.semaine = cohortes.semaine_0 + interval '3 weeks') as semaine_3
from cohortes
left join activite on activite.user_id = cohortes.id
group by 1
order by 1 desc;
```

### Le droit Pro, vu de la base

```sql
select
  count(*) filter (where is_pro) as pro,
  count(*) filter (where is_pro and period_type = 'trial') as en_essai,
  count(*) filter (where is_pro and not will_renew) as ne_se_renouvellera_pas,
  count(*) filter (where is_pro and store = 'stripe') as via_le_site,
  count(*) filter (where is_pro and store = 'app_store') as via_l_app_store
from public.entitlements;
```

C'est un **reflet** de RevenueCat, écrit par son webhook
(`supabase/functions/revenuecat-webhook/index.ts`). Pratique pour croiser l'abonnement avec
l'usage dans une seule requête ; pour le chiffre d'affaires lui-même, c'est RevenueCat qui
fait foi (section 3).

### Le coût des générations

```sql
select day, fn, sum(count) as appels, count(distinct user_id) as personnes
from public.ai_usage
where day > current_date - 30
group by 1, 2
order by 1 desc, 2;
```

`ai_usage` sert d'abord au quota, mais c'est aussi le seul endroit qui dise combien de fiches
sont écrites par jour — donc ce que fal.ai va facturer.

### D'où viennent les inscrits, et la liste d'attente

```sql
select country_code, study_level, count(*) as comptes
from public.profiles
where created_at > now() - interval '30 days'
group by 1, 2
order by 3 desc;

select source, count(*) as adresses
from public.waitlist
group by 1
order by 2 desc;
```

Le `source` de la liste d'attente distingue déjà `landing`, `hero`, `pricing`, `questions` :
c'est la seule mesure de « quelle section de la page d'accueil convertit » qui existe
aujourd'hui.

---

## 3. RevenueCat — la vérité de l'abonnement

RevenueCat détient le droit sur les deux plateformes : Apple encaisse sur iPhone, Stripe
encaisse sur le site, et **les deux remontent chez RevenueCat** via son intégration Stripe
(`docs/revenuecat.md`, section 12). C'est donc le seul écran qui additionne correctement un
abonné App Store et un abonné web.

Ce qu'on y lit sans rien installer : abonnés actifs, essais démarrés, **taux de conversion
d'essai**, revenu net par mois, résiliations, remboursements, cohortes de revenu par mois
d'acquisition, et la répartition par magasin.

Deux réglages qui changent la valeur de l'outil :

- **`app_user_id` = l'identifiant Supabase.** C'est déjà le cas (`PurchasesBridge.identify`
  sur iOS, `client_reference_id` au checkout web). Sans ça, un même étudiant compterait deux
  fois. C'est aussi ce qui permet de joindre RevenueCat et la base sur la même clé.
- **Les cohortes** demandent que les essais soient déclarés comme tels côté produit ; ils le
  sont.

---

## 4. Stripe — l'encaissement du site, rien de plus

Stripe sait ce que RevenueCat ne sait pas bien : les paiements **échoués**, les litiges, les
remboursements, la TVA, et le détail d'une facture. C'est là qu'on va quand quelqu'un écrit
« j'ai payé et je n'ai pas l'accès ».

Ce n'est pas le bon endroit pour le suivi produit : Stripe ignore les abonnés iPhone, donc
tout chiffre d'abonnement lu chez Stripe est un sous-ensemble. **Le revenu se lit chez
RevenueCat, l'incident se lit chez Stripe.**

---

## 5. Les angles morts

Ce sont des trous connus, pas des oublis. Les nommer évite de croire qu'un chiffre existe.

### L'accueil iPhone est invisible

Le parcours iOS a **vingt écrans** (`Micabo/Features/Onboarding/OnboardingStep.swift`), il
vit dans `UserDefaults`, et rien n'en sort avant la création du compte. On sait donc combien
de gens finissent (le compte apparaît), jamais **où** les autres s'arrêtent — alors que c'est
sur ce parcours qu'il y a un paywall.

Trois façons de le combler, par coût croissant :

1. **App Store Connect** donne déjà impressions → téléchargements → et une rétention grossière.
   Ça situe le problème (acquisition ou accueil) sans une ligne de code.
2. **Écrire l'étape atteinte en base** au moment de la création du compte : une colonne, une
   valeur, aucun tiers. Ça ne dit rien de ceux qui ne créent jamais de compte — c'est-à-dire
   exactement ceux qu'on cherche.
3. **Un SDK de mesure mobile.** TelemetryDeck est le seul qui reste cohérent avec la
   politique de confidentialité actuelle (pas d'IDFA, pas d'identifiant persistant).
   Firebase Analytics répondrait mieux et coûterait un bandeau de consentement et un
   paragraphe de plus dans la page vie privée.

### On ne peut pas relier un visiteur à un compte

Vercel Web Analytics est anonyme par construction. On obtient des *taux* (« 4 % des visiteurs
créent un compte »), jamais un chemin individuel (« cette personne est venue de TikTok, puis
s'est abonnée »). Recoller les deux demande un identifiant posé sur l'appareil, donc un
bandeau de consentement, donc un autre outil (PostHog, Plausible avec l'extension adéquate).

Le choix actuel est assumé : **pas de bandeau, pas de cookie, pas de pistage** — c'est écrit
dans la politique de confidentialité, et le public est en partie mineur. Y renoncer est une
décision de produit, pas une case à cocher.

### On ne sait pas si un compte vient du site ou de l'iPhone

`profiles` ne porte aucune colonne de plateforme. Le raccourci « `learning_goals` non vide
donc iPhone » marche aujourd'hui par accident (le site ne les écrit pas) et cassera au
premier changement d'accueil web.

Le correctif est une colonne, `profiles.signup_platform` (`'web' | 'ios'`), écrite une fois à
la création : par `saveOnboarding` côté site (`web/lib/actions/onboarding.ts`) et par
`CloudSync.push()` côté iPhone. C'est la mesure manquante la moins chère du lot.

---

## 6. Dans quel ordre je le ferais

1. **Activer Web Analytics dans Vercel.** Le code est posé, il manque le clic. Un jour de
   données suffit à savoir si la page d'accueil est vue.
2. **Mettre trois requêtes en favoris** dans le SQL editor : comptes par jour, réviseurs par
   jour, droits Pro. Les regarder chaque semaine vaut mieux qu'un tableau de bord qu'on
   construit et qu'on n'ouvre plus.
3. **Lire l'entonnoir `/commencer/*`** après deux semaines de collecte, et corriger l'écran
   qui perd le plus. C'est le seul endroit où la mesure se transforme en travail évident.
4. **Ajouter `signup_platform`.** Sans ça, chaque chiffre de la base mélange deux produits.
5. **Instrumenter l'accueil iPhone** — et seulement si App Store Connect montre que les
   téléchargements ne deviennent pas des comptes. Sinon c'est du code pour une courbe.

Ce qui n'est pas dans cette liste, volontairement : un tableau de bord interne. Tant que les
chiffres tiennent dans cinq requêtes, l'écrire coûte plus cher que le lire.
