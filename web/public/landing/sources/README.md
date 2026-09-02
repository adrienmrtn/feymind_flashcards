# Exemples de documents — vitrine

Les cases de « Micabo transforme tes documents » cherchent ici un fichier
par format. Le nom du fichier est l’`id` de la source, sans autre dossier.

| Fichier | Case |
| --- | --- |
| `polycopie-pdf.webp` | Polycopié PDF |
| `photo-notes.webp` | Photo de tes notes |
| `document-word.webp` | Document Word |
| `video-youtube.webp` | Vidéo YouTube |
| `diapositives.webp` | Diapositives de cours |
| `manuel-scanne.webp` | Manuel scanné |
| `notes-manuscrites.webp` | Notes manuscrites |

L’extension attendue est **`.webp`**, **16 / 9**, autour de **1640 × 960**.
Les sept extraits sont des natures mortes inventées (une matière par case),
pas des icônes et pas des captures de documents réels.

Tant que le fichier n’est pas dans ce dossier, la vitrine ne doit **pas**
pointer son URL : un `.webp` absent répond 404, et Search Console le compte
comme une ressource de page qui n’a pas pu être chargée.

Chemin depuis la racine du dépôt :

```
web/public/landing/sources/notes-manuscrites.webp
```

Sur le site, ça se sert à `/landing/sources/notes-manuscrites.webp`.
