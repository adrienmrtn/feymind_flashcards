# Kit de marque Micabo — Mika

Mika est la mascotte de Micabo : un petit personnage noir aux yeux blancs, crayon à la main, avec une étincelle au bout du crayon (l'IA qui transforme un cours en fiches).

Ce kit contient l'icône de l'app pour toutes les plateformes, Mika en images fixes, 13 animations et un composant React Native prêt à brancher.

## Pour voir le résultat tout de suite

- `apercu-animations.gif` : les 13 animations côte à côte.
- `animations/mika-demo.html` : ouvrir dans un navigateur, cliquer sur une humeur, changer le fond.

## Contenu

| Dossier | Contenu |
| --- | --- |
| `icone/` | Icône 1024 (App Store), 512 (Google Play), jeux complets iOS, Android, Expo et web, image d'écran de lancement |
| `mika/` | 10 expressions fixes en PNG transparent 1024 px, en deux versions : étincelle blanche (`sur-fond-bleu/`) et étincelle bleue (`sur-fond-clair/`) |
| `animations/lottie/` | 13 animations Lottie autonomes (images incluses), utilisables sur iOS, Android, web, Flutter |
| `animations/apercus/` | Un GIF par animation, pour se repérer |
| `react-native/` | Composant `Mika.tsx`, animations allégées, images 512 px, fichiers Expo |
| `marque/` | Couleurs de la marque (`tokens.json`, `tokens.ts`) |
| `PROMPT-CLAUDE-CODE.md` | Le message à coller dans Claude Code pour intégrer le tout |

## Couleurs

| Nom | Hex | Usage |
| --- | --- | --- |
| Bleu Micabo | `#3870FE` | Fond de l'icône, couleur principale |
| Noir Mika | `#050507` | Corps de Mika |
| Blanc | `#FFFFFF` | Yeux, étincelle sur fond bleu |
| Jaune crayon | `#F7B41F` | Accent (à utiliser avec parcimonie) |
| Rose gomme | `#E3596C` | Accent secondaire, erreurs douces |

Ces valeurs sont mesurées sur l'icône. `marque/tokens.json` ajoute une gamme de bleus plus clairs et plus foncés, calculée à partir du bleu Micabo : c'est une proposition, à ajuster selon l'interface.

Le kit ne définit ni typographie ni logo écrit « Micabo » : ils n'existent pas encore.

## Les 13 animations

Toutes font 1024 × 1024, 30 images par seconde, fond transparent.

| Humeur | Type | Durée | Quand l'utiliser |
| --- | --- | --- | --- |
| `idle` | boucle | 5 s | État par défaut : respire, cligne des yeux, l'étincelle scintille |
| `appear` | ponctuelle | 1,5 s | Arrivée sur un écran, onboarding |
| `wave` | ponctuelle | 2,5 s | Bienvenue, premier lancement |
| `happy` | ponctuelle | 2 s | Bonne réponse, action réussie (les yeux sourient) |
| `wink` | ponctuelle | 1,5 s | Encouragement, astuce |
| `celebrate` | ponctuelle | 3 s | Session terminée, série de jours, objectif atteint |
| `think` | boucle | 3 s | Chargement, l'IA analyse le cours |
| `write` | boucle | 2 s | Génération des fiches en cours |
| `look` | ponctuelle | 3,3 s | Écran vide, attente d'une action |
| `surprise` | ponctuelle | 1,7 s | Nouveauté, récompense débloquée |
| `shake` | ponctuelle | 1,7 s | Mauvaise réponse (un « non » doux, yeux plissés) |
| `sad` | boucle | 4 s | Erreur, hors-ligne, série perdue |
| `sleep` | boucle | 5 s | Inactivité, rappel de révision |

Les animations ponctuelles finissent toutes dans la pose de repos, et en partent aussi (sauf `appear`, qui arrive par le bas) : elles s'enchaînent avec `idle` sans saut.

Mika n'a pas de bouche : son sourire passe par les yeux, qui se plissent en arc.

## Règles d'utilisation de Mika

1. **Mika est un buste.** Son corps est coupé en bas de l'image. Il faut toujours le coller au bord bas d'une carte, de l'écran ou d'une pastille, comme s'il en sortait. Ne jamais le laisser flotter au milieu d'une page : on verrait la coupe.
2. **Pour l'utiliser n'importe où**, le mettre dans une pastille bleue ronde ou arrondie (`frame="circle"` dans le composant).
3. **L'étincelle est blanche.** Sur un fond clair elle disparaît : utiliser la version à étincelle bleue (`sur-fond-clair/`, ou `sparkleColor` dans le composant).
4. **Taille minimale :** 64 points pour une animation. En dessous, utiliser une image fixe.
5. **Deux Mika animés au maximum** sur un même écran.
6. Ne pas déformer Mika, ne pas changer ses couleurs, ne pas lui ajouter de bouche ni d'accessoires.

## Icône de l'app

- App Store : `icone/micabo-icone-1024.png` (carrée, sans transparence ; Apple arrondit les coins).
- Google Play : `icone/google-play/micabo-icone-512.png`.
- Android : icône adaptative dans `icone/android/res/` (premier plan, fond `#3870FE`, version monochrome pour les icônes à thème d'Android 13).
- Expo : `icone/expo/` (`icon.png`, `adaptive-icon-foreground.png`, `adaptive-icon-monochrome.png`, `splash-icon.png`, `notification-icon.png`, `favicon.png`).
- Web : `icone/web/`.
- `icone/ecran-lancement-1290x2796.png` : Mika en bas d'un écran bleu, pour un écran d'accueil ou d'onboarding dessiné dans l'app.

## Ce qu'il faut savoir

- Les fichiers sont construits à partir d'une copie 1024 × 1024 compressée de l'icône. Le rendu est propre, mais si vous avez le PNG d'origine, le kit peut être régénéré à partir de lui pour une netteté maximale.
- Les animations ont été vérifiées image par image dans un navigateur (lecteur Lottie web) et le composant passe la vérification TypeScript avec `lottie-react-native` 7.5. Elles n'ont pas été testées sur un iPhone ou un téléphone Android : à contrôler au premier lancement.
- Le bras et le crayon de Mika ne bougent que de quelques degrés : c'est une image découpée, pas un modèle 3D.
