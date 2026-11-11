# Mika — animations corps entier, fond transparent

23 animations de Mika en entier (5 tentacules + le bras au crayon), sans fond, 24 images/s.

## Contenu

- `apng/` — PNG animés transparents (`mika-<nom>.png`). Le format demandé : un seul fichier PNG par animation.
- `webp/` — les mêmes en WebP animé transparent, environ 2× plus légers. À préférer dans l'app.
- `images-fixes/` — 12 poses en PNG transparent 1024 px (neutre, sourire, coucou, saut, course, nage…).
- `apercus/` — deux GIF pour tout voir d'un coup d'œil (sur fond bleu Micabo).
- `animations.json` — nom, durée, nombre d'images, boucle ou non, taille, chemin des fichiers.
- `demo.html` — à ouvrir dans un navigateur : toutes les animations, avec choix du fond.
- Le zip `mika-sequences-png.zip` (à part) contient chaque animation image par image en PNG, pour After Effects, Rive, une sprite sheet, etc.

## Les animations

| Nom | Ce que fait Mika | Durée | Lecture | Taille |
|---|---|---|---|---|
| `repos` | Repos : flotte, respire, cligne des yeux | 3.0 s | boucle | 512×512 |
| `marche` | Marche sur place (à déplacer dans l’app) | 2.0 s | boucle | 512×512 |
| `course` | Course sur place | 1.33 s | boucle | 512×512 |
| `nage` | Nage : se propulse avec ses tentacules | 1.67 s | boucle | 512×512 |
| `danse` | Danse | 2.0 s | boucle | 512×512 |
| `reflexion` | Réflexion : tapote, regarde l’étincelle | 3.0 s | boucle | 512×512 |
| `ecriture` | Écriture : gribouille, étincelles | 2.0 s | boucle | 512×512 |
| `triste` | Tristesse | 3.0 s | boucle | 512×512 |
| `sommeil` | Sommeil | 4.0 s | boucle | 512×512 |
| `saut` | Saut de joie | 1.58 s | une fois | 512×512 |
| `celebration` | Célébration : deux sauts, étincelles | 2.67 s | une fois | 512×512 |
| `coucou` | Coucou avec un tentacule | 2.17 s | une fois | 512×512 |
| `surprise` | Surprise : sursaut, tentacules écartés | 1.5 s | une fois | 512×512 |
| `clin-doeil` | Clin d’œil | 1.5 s | une fois | 512×512 |
| `oui` | Oui : hoche la tête | 1.5 s | une fois | 512×512 |
| `non` | Non : secoue la tête | 1.67 s | une fois | 512×512 |
| `regard` | Regarde à gauche, à droite, en haut | 3.0 s | une fois | 512×512 |
| `apparition` | Apparition : tombe du haut et atterrit | 1.33 s | une fois | 512×512 |
| `etirement` | Étirement et bâillement | 2.67 s | une fois | 512×512 |
| `traversee-marche` | Traverse l’écran en marchant | 5.25 s | boucle | 680×440 |
| `traversee-nage` | Traverse l’écran à la nage | 5.0 s | boucle | 680×440 |
| `entree` | Arrive en courant et freine | 1.92 s | une fois | 680×440 |
| `sortie` | Prend son élan et file | 1.5 s | une fois | 680×440 |

Les quatre dernières (`traversee-*`, `entree`, `sortie`) sont sur un cadre large : Mika traverse l'écran, entre par la gauche ou sort par la droite. Les autres se jouent sur place dans un carré, à déplacer soi-même si besoin (`marche`, `course` et `nage` bouclent sans à-coup).

## Dans l'app (React Native)

```tsx
import { Image } from 'expo-image';

<Image source={require('./webp/mika-marche.webp')} style={{ width: 220, height: 220 }} contentFit="contain" autoplay />
```

`expo-image` lit le WebP animé et le PNG animé avec la transparence. Le composant `Image` de base de React Native ne les anime pas partout, donc passer par `expo-image`. Pour une animation « une fois », afficher ensuite l'image fixe correspondante ou revenir sur `repos`.

Couleurs : bleu de fond Micabo `#3674FD` (mesuré sur le visuel), corps noir, étincelle blanche avec un fin liseré bleu pour rester visible sur fond clair.

## À savoir

- Tout est animé à partir d'une seule image de Mika, déformée comme une marionnette (pas de 3D) : les mouvements restent de face, il ne se retourne pas.
- La source est une copie 1024 px ; les animations sont en 512 px (680×440 pour les traversées), les images fixes en 1024 px. Au-delà, ça devient flou.
