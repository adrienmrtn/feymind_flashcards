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

Ce qui reste à faire, et qui pèse plus que tout le code ci-dessus :

1. **Déclarer le site dans la Search Console** sur `https://www.micabo.app`, puis demander
   l'indexation de `/`. Sans ça, la sortie du blocage peut prendre des semaines.
2. **Y déposer le sitemap** : `https://www.micabo.app/sitemap.xml`.
3. **Des liens entrants.** Pour une marque inventée, c'est ce qui décide du premier rang. Une
   page App Store qui pointe vers le site, un compte social, un dépôt public : trois liens
   cohérents valent plus que n'importe quelle balise.
4. **Écrire de vraies pages** quand il y aura de quoi. Trois adresses, dont deux légales, est
   une surface mince : les sitelinks pointent vers des pages, et il en faut à montrer.
