# Les supports et les modes de révision (iPhone)

Ce qu'on donne à Mika pour écrire une leçon, et les façons de la réviser une fois écrite.
Tout ce qui est décrit ici se fait **sur l'appareil** : aucune fonction serveur n'a été
ajoutée. Les supports envoient leur texte par le chemin existant (`generate-lesson`, qui ne
connaît que les sources `text`, `pdf`, `photo`, `audio`, `youtube`, `docx`, `mixed` :
`normalizeSource` dans `supabase/functions/generate-lesson/gate.ts`).

## 1. Les supports (feuille du « + »)

`HomeSourcesSheet` (`Micabo/Features/Import/SourcesSheet.swift`) : Mika posé au bas de sa carte,
la leçon offerte rappelée tant qu'elle reste, puis une grille de neuf supports, trois par rangée,
et à part les flashcards déjà faites. Aucune couronne : lire se fait sur l'appareil, la porte du
gratuit vient au moment d'écrire la leçon (`LessonAllowance.locksImport` rend toujours `false`,
`sendRoute` décide).

| Support | Lecture sur l'appareil | Source envoyée |
| --- | --- | --- |
| PDF ou Word | `PDFImportService` (texte puis OCR), `DocxImportService` | `pdf` / `docx` |
| Diapos (.pptx) | `SlidesImportService` : `ppt/slides/slideN.xml` dans l'ordre des numéros, plus les notes du présentateur. Keynote et `.ppt` : une phrase dit comment exporter. | `pdf` |
| Photos | Scanner ou photothèque, OCR Vision (`OnDeviceOCR`) | `photo` |
| Notes manuscrites | Le scanner d'abord, même OCR. Vision `.accurate` lit l'écriture à la main ; la langue des cours passe en tête, puis l'anglais et le français, avec la détection automatique (avant : français et anglais seulement). | `photo` |
| Page web | `WebPageImportService` : la page est téléchargée, débarrassée de son décor (scripts, menus, pieds de page), l'`<article>` ou le `<main>` gardé, les entités décodées. Un lien PDF est lu comme un PDF ; un lien YouTube part par le support YouTube. | `text` |
| YouTube | `YouTubeImportService` (sous-titres puis repli serveur existant) | `youtube` |
| Cours en direct | L'enregistreur (`VoiceRecorder`, 90 min), qui continue écran verrouillé, puis `AudioTranscriber` | `audio` |
| Audio | Un mémo ou un fichier, même transcription | `audio` |
| Texte | Un copier-coller | `text` |
| **Flashcards** | Anki (`.apkg`, `.colpkg`, export `.txt`/`.csv`, `AnkiPackageReader`) ou copier-coller Quizlet (`FlashcardPaste` : terme ⇥ définition, ou ` - `, `:`, `;`, `,`) | aucune |

Les flashcards ne passent pas par la génération : `DeckLessonBuilder` crée un paquet
(`CourseSource.deck`, qui ne consomme pas la leçon offerte) et en fait une leçon complète sur
l'appareil : des parties d'une douzaine de cartes, chacune avec ses notes (le glossaire de ses
cartes), un quiz tiré des cartes (la bonne réponse parmi celles de trois autres cartes, une
question sur deux à l'envers) et ses flashcards, prêtes dès aujourd'hui. Le deck s'ouvre aussitôt.

## 2. Les modes de révision d'une leçon

Une rangée « Réviser autrement » sous l'en-tête de la leçon (`RevisionModesRow`,
`Micabo/Features/Lesson/RevisionModes.swift`), construite depuis le contenu de la leçon
(`LessonDigest` : les notes de chaque thème, à défaut ses cartes).

- **Écouter** (`ListenView`, `LessonSpeaker`) : la leçon lue par `AVSpeechSynthesizer`, dans la
  meilleure voix installée pour la langue de la leçon ; une phrase à la fois, chapitres, 1× / 1,25× /
  1,5×, pause, chapitre suivant ou précédent. Session audio `playback` + `UIBackgroundModes`
  `audio` : la lecture continue écran verrouillé, avec les commandes de l'écran de verrouillage.
- **À voix haute** (`VoiceRecallView`, `VoiceRecallListener`, `SpokenAnswer`) : la carte pose la
  question (à l'écran et lue), l'élève répond en parlant ; `SFSpeechRecognizer` sur l'appareil
  quand il sait le faire. La comparaison est tolérante : casse, accents et ponctuation ignorés,
  mots vides retirés, une faute ou une terminaison près, mots collés (« photo synthèse »).
  Verdict : juste, presque, pas encore ; l'élève garde le dernier mot avec « Je savais » (`good`)
  ou « Pas encore » (`again`), qui notent la carte dans le SRS existant (`LessonReview.rate`).
- **Carte mentale** (`MindMapView`, `MindMap`) : la leçon, ses thèmes en branches colorées, et
  sous chaque thème ses notions (sous-titres, termes définis, dates, formules légendées) avec
  leurs détails. Une liste repliable plutôt qu'un plan à faire glisser : lisible au pouce, en
  Dynamic Type et de droite à gauche.
- **Fiche PDF** (`SheetExportView`, `SheetExporter`) : la fiche mise en page en A4 avec la police
  de l'app, numérotée, partagée par la feuille de partage (Fichiers, AirDrop, impression).

## 3. La porte du gratuit

La règle suit celle de l'app — ce qui relit est à tous, ce qui fait travailler davantage a son
essai offert puis passe dans Pro, comme Mika (une question) et l'examen blanc (un). **Aucun prix
ne change.** (`RevisionModeAllowance`)

| | Sans abonnement | Pro |
| --- | --- | --- |
| Lire un support, importer des flashcards | Gratuit | Gratuit |
| Écrire la leçon depuis les supports | La leçon offerte, puis paywall (règle existante) | Oui |
| Écouter, carte mentale | Gratuit | Oui |
| À voix haute | Une séance offerte, puis `PaywallTrigger.voiceRecall` | Oui |
| Fiche PDF | `PaywallTrigger.exportSheet` | Oui |

## 4. Textes et tests

Clés `ios.sup.*` dans `IosI18nCatalogs.swift` et `Locales/I18n+*.swift`, dans les 26 langues ;
les phrases système du micro et de la dictée (`InfoPlist.strings`) disent aussi l'écoute des
réponses. Tests : `MicaboTests/SupportsTests.swift` (diapos sur un `.pptx` fabriqué dans le
test, paquet collé, réponses orales, carte mentale, écoute, deck, page web, porte, PDF) et
`MicaboTests/SupportsRenderTests.swift` (rendus `sup-*`, français jour et nuit, allemand, arabe).
