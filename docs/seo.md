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
| Manifeste et icônes | `web/app/manifest.ts`, `web/public/icon.svg` |
| Ancres de la vitrine | `web/lib/landing-sections.ts` |

L'hôte canonique est écrit en clair : `https://www.micabo.app`. Il ne suit pas
`VERCEL_PROJECT_PRODUCTION_URL`, qui rend le domaine le plus court — donc `micabo.app`, qui
redirige en 307 vers `www`. Une balise canonique qui pointe vers une redirection fait
dépenser un aller-retour par page, et deux hôtes qui servent le même texte se disputent la
même requête.

Si la redirection est un jour inversée (`www` → nu), c'est cette constante qu'il faut
changer, et elle seule.

## Le favicon : quoi déposer, exactement

Le SVG est déjà là (`web/public/icon.svg`) et suffit aux navigateurs de bureau modernes. Les
fichiers ci-dessous complètent les plateformes qui ne lisent pas le SVG. Ils vont tous dans
**`web/public/`**, avec **ces noms exacts** — le code les cherche là.

| Fichier | Format | Taille | À quoi il sert |
| --- | --- | --- | --- |
| `icon.svg` | SVG | vectoriel | Onglets de bureau. **Déjà en place.** |
| `apple-touch-icon.png` | PNG 24 bits, **sans transparence** | 180 × 180 | Écran d'accueil iOS |
| `icon-192.png` | PNG | 192 × 192 | Android, onglets anciens |
| `icon-512.png` | PNG | 512 × 512 | Splash Android, installation |
| `icon-maskable-512.png` | PNG | 512 × 512 | Android qui rogne en cercle |
| `favicon.ico` | ICO, `16 + 32` en un seul fichier | — | Vieux Windows, agrégateurs |

### Le format le plus optimisé, si on n'en fait qu'un

**SVG.** Un seul fichier, net à toutes les tailles, et de l'ordre de 300 octets contre
plusieurs kilo-octets pour un PNG 512. C'est celui qui est déjà là.

Le reste n'est pas du zèle : iOS ignore le SVG et affiche une capture grise de la page si
`apple-touch-icon.png` manque, et Android a besoin d'un PNG pour l'installation.

### Les trois règles qui décident du résultat

**Dessiner pour 16 px, pas pour 512.** C'est la taille à laquelle un favicon est vu 99 % du
temps. Un logotype complet y devient une tache. Une forme pleine et une seule lettre, oui —
c'est ce que fait `icon.svg` : tuile verte, un `M` blanc tracé.

**Pas de transparence sur `apple-touch-icon.png`.** iOS pose le PNG sur un fond noir quand la
couche alpha est vide. Fond plein, coins carrés : iOS arrondit lui-même.

**De la marge sur la version maskable, et seulement sur elle.** Android rogne jusqu'à 20 % de
chaque bord. Le dessin doit tenir dans le cercle central de 409 px sur les 512, sinon la
lettre est coupée. C'est le seul fichier qui a besoin d'une composition à part.

### Générer les PNG depuis le SVG

```bash
cd web/public

# Les tailles courantes
for s in 192 512; do
  npx --yes sharp-cli -i icon.svg -o "icon-$s.png" resize $s $s
done

# iOS : fond plein, aucune transparence
npx --yes sharp-cli -i icon.svg -o apple-touch-icon.png \
  resize 180 180 -- flatten --background '#0b8a66'

# Android maskable : le dessin à 64 %, centré, le reste en fond
npx --yes sharp-cli -i icon.svg -o icon-maskable-512.png \
  resize 328 328 -- extend --top 92 --bottom 92 --left 92 --right 92 \
  --background '#0b8a66'
```

Pour le `.ico`, `png-to-ico` accepte plusieurs tailles et les empile dans un seul fichier :

```bash
npx --yes png-to-ico icon-192.png > favicon.ico
```

Rien à déclarer après coup : `web/app/layout.tsx` et `web/app/manifest.ts` pointent déjà vers
ces noms.

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
