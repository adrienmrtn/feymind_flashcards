# Le référencement du site, et le favicon

## Ce qui bloquait

Le site répondait ceci, en production :

```
User-Agent: *
Disallow: /
```

et, dans chaque page :

```html
<meta name="robots" content="noindex, nofollow" />
```

C'est exactement ce que décrit le message de la Search Console : Google ne pouvait pas lire
la page, donc il n'avait aucun texte pour composer l'extrait sous le titre. Il pouvait encore
connaître l'adresse — par un lien entrant — et l'afficher nue.

`Disallow` et `noindex` ne s'additionnent pas, ils **se contrarient**. Une page interdite à
l'exploration ne peut pas être lue, donc son `noindex` ne peut pas être vu. C'est la raison
pour laquelle les écrans privés sont maintenant fermés par en-tête `X-Robots-Tag` et laissés
explorables : sans exploration, la consigne n'arriverait jamais.

## Ce qui est en place

| Élément | Fichier |
| --- | --- |
| Ouverture de l'index, production seulement | `web/lib/config.ts`, `IS_INDEXABLE` |
| Hôte canonique unique | `web/lib/config.ts`, `CANONICAL_URL` |
| `robots.txt` | `web/app/robots.ts` |
| `sitemap.xml` | `web/app/sitemap.ts` |
| Titres, descriptions, Open Graph, canoniques | `web/app/layout.tsx` + chaque `page.tsx` |
| `Organization`, `WebSite`, `SoftwareApplication` | `web/components/landing/StructuredData.tsx` |
| `noindex` des écrans privés | `web/next.config.ts`, `X-Robots-Tag` |
| Manifeste et icônes | `web/app/manifest.ts`, `web/public/icon.svg`, `BrandMark` |
| Ancres de la vitrine | `web/lib/landing-sections.ts` |

L'hôte canonique est écrit en clair : `https://www.micabo.app`. Il ne suit pas
`VERCEL_PROJECT_PRODUCTION_URL`, qui rend le domaine le plus court — donc `micabo.app`, qui
redirige en 307 vers `www`. Une balise canonique qui pointe vers une redirection fait
dépenser un aller-retour par page, et deux hôtes qui servent le même texte se disputent la
même requête.

Si la redirection est un jour inversée (`www` → nu), c'est cette constante qu'il faut
changer, et elle seule.

## Le favicon : le stylo, coins arrondis

Le rendu 3D (stylo blanc sur bleu) est la marque. Le fichier source est un **carré aux
coins droits** : on lui pose un masque arrondi (~22 %) partout où l'icône s'affiche
dans un onglet, une barre ou à côté du mot « Micabo ». iOS applique son propre masque :
`apple-touch-icon.png` reste donc un carré plein.

Tous les fichiers vivent dans `web/public/`. On les régénère depuis le PNG source :

```bash
node web/scripts/build-icons.mjs chemin/vers/stylo.png
```

| Fichier | Format | Taille | À quoi il sert |
| --- | --- | --- | --- |
| `icon.svg` | SVG + PNG embarqué, coins arrondis | — | Onglets de bureau |
| `icon.png` | PNG, coins arrondis | 256 × 256 | Logo dans les pages |
| `icon-32.png` / `icon-64.png` | PNG, coins arrondis | 32 / 64 | Relais PNG |
| `icon-192.png` | PNG, coins arrondis | 192 × 192 | Android, onglets anciens |
| `icon-512.png` | PNG, coins arrondis | 512 × 512 | Splash, `Organization.logo` |
| `apple-touch-icon.png` | PNG 24 bits, **sans transparence** | 180 × 180 | Écran d'accueil iOS |
| `icon-maskable-512.png` | PNG | 512 × 512 | Android qui rogne en cercle |
| `favicon.ico` | ICO, `16 + 32` | — | Vieux Windows, agrégateurs |

### Les trois règles qui restent

**Pas de transparence sur `apple-touch-icon.png`.** iOS pose le PNG sur un fond noir quand la
couche alpha est vide. Fond plein, coins carrés : iOS arrondit lui-même.

**De la marge sur la version maskable, et seulement sur elle.** Android rogne jusqu'à 20 % de
chaque bord. Le stylo doit tenir dans le cercle central, sinon la pointe est coupée.

**`icon.svg` reste sans commentaire.** Un SVG est du XML : un `--` dans un commentaire, ou un
accent mal encodé, fait échouer le parseur en silence et l'onglet retombe sur l'icône par
défaut.

```bash
xmllint --noout web/public/icon.svg && echo OK
```

Rien à déclarer après une régénération : `web/app/layout.tsx` et `web/app/manifest.ts`
pointent déjà vers ces noms. Le composant `BrandMark` lit `icon.png`.

## Les sitelinks : ce qui se fait et ce qui ne se fait pas

Les liens qui apparaissent sous un résultat ne se déclarent pas. **Il n'existe aucune balise
pour les demander** — ni `sitelinks`, ni un champ de `schema.org`. Google les choisit à partir
des pages qu'il a explorées, de leurs titres et des liens internes qui y mènent. Le
`SearchAction` que l'on voit encore recommandé pour la boîte de recherche est abandonné depuis
2023 ; il n'est pas dans le code.

Ce qui rend leur apparition possible, et qui est fait :

- des pages distinctes et explorables, avec des titres différents (le sitemap en liste trois)
- une navigation en dur, en haut et dans le pied, avec des intitulés qui disent un sujet
- des sections nommées (`#methode`, `#mode-examen`, `#iphone`, `#questions`) : Google en tire
  parfois des liens vers une partie de la page, sur les pages longues
- des données structurées `Organization` qui rattachent le mot « Micabo » à une entité, au
  lieu de laisser le moteur proposer une correction orthographique

## Ce que tu as à faire de ton côté

Le code ouvre la porte. Google n'entre pas tout seul. Voici l'ordre, et rien d'autre n'est
obligatoire.

### 1. Faire explorer le site

1. Ouvre [Google Search Console](https://search.google.com/search-console) et ajoute la
   propriété **`https://www.micabo.app`** (préfixe d'URL, avec le `www`). Si tu as aussi
   `https://micabo.app` sans www, ajoute-la séparément : ce n'est pas le même hôte.
2. Vérifie la propriété. Le plus simple : l'enregistrement DNS que Vercel t'a déjà fait
   poser, ou le fichier HTML que Search Console propose de mettre dans `web/public/`.
3. Dans **Sitemaps**, dépose exactement : `https://www.micabo.app/sitemap.xml`.
4. Ouvre **Inspection d'URL**, colle `https://www.micabo.app/`, demande un test en direct,
   puis **Demander l'indexation**. Sans cette demande, la sortie de l'ancien `Disallow: /`
   peut prendre des semaines.
5. Contrôle `https://www.micabo.app/robots.txt` : en production il doit **autoriser** `/`
   et citer le sitemap. S'il dit encore `Disallow: /`, le déploiement n'est pas celui de
   production (`IS_INDEXABLE` ne s'allume que si `VERCEL_ENV=production`).

Répète l'inspection pour `/methode`, `/mode-examen` et `/micabo-ou-anki` : ce sont les
pages que Google peut proposer sous le résultat principal.

### 2. Les sitelinks (les sous-liens sous le résultat)

**Tu ne peux pas les demander.** Il n'existe ni case Search Console, ni balise, ni
`schema.org` pour ça. Google les choisit quand il connaît assez le site : pages distinctes,
titres différents, liens internes clairs. C'est déjà en place (vitrine, trois pages de
contenu, pied de page, sitemap).

Ce qui les fait apparaître, de ton côté :

1. L'exploration ci-dessus, jusqu'à ce que ces pages soient **indexées** (pas seulement
   « découvertes »).
2. Des recherches sur le mot « Micabo » qui aboutissent. Les sitelinks viennent après que
   le résultat principal est stable, souvent plusieurs semaines.
3. **Des liens depuis l'extérieur** vers `https://www.micabo.app` : fiche App Store, compte
   Instagram / TikTok / LinkedIn, dépôt GitHub public. Pour une marque inventée, trois
   liens cohérents pèsent plus qu'une balise de plus.
4. Ne pas pointer ces liens vers `micabo.app` sans www, ni vers une URL `*.vercel.app` :
   Google verrait deux sites.

On ne choisit pas les sitelinks, et on ne les retire plus : l'outil de Search Console
qui les « démotait » n'existe plus. Un mauvais lien disparaît seulement si la page
elle-même est moins mise en avant, ou retirée de l'index.

### 3. Ensuite seulement

- Bing Webmaster Tools, même sitemap, si tu veux aussi Bing.
- Apple Search (App Store) est un autre index : le site n'y change rien, la fiche App
  Store si.
- Écrire d'autres pages publiques quand il y aura un sujet. Les sitelinks pointent vers
  des pages, pas vers des ancres `#methode`.
