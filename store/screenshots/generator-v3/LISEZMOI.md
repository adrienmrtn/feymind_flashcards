# Images App Store — DA V3

Les sept images de la fiche App Store (iPhone 6,9″, PNG 1320 × 2868 sans transparence),
dans 27 langues. Elles remplacent celles de `store/screenshots/generator/` (ancienne DA).

- `index.html` : la page, 7 × 1320 px de large. Fond clair (V3 jour), coque bleu Micabo,
  écrans de l'app en marine (V3 nuit). Ouverture : Mika en héros, puis la fiche.
- `i18n.js` : tous les textes, langue par langue. Dans le téléphone, les libellés viennent
  du catalogue iOS (`Micabo/Services/I18n`) ; l'app n'existant pas en hébreu, japonais ni
  norvégien, son écran y reste en anglais. Seule la note vérifiable est affichée (5,0 sur
  l'App Store).
- `render.mjs` : écrit `store/screenshots/<langue>/01-…07-….png`.

```sh
npm i --no-save playwright            # ou PLAYWRIGHT=<chemin vers playwright>
CHROME=/usr/bin/google-chrome node store/screenshots/generator-v3/render.mjs        # toutes
CHROME=/usr/bin/google-chrome node store/screenshots/generator-v3/render.mjs fr de  # certaines
```

Pour voir une langue dans un navigateur : `index.html?lang=de`.

Les titres prennent chacun la plus grande taille qui tient sur la largeur ; un titre trop long
rétrécit, mieux vaut alors le raccourcir dans `i18n.js` (`render.mjs` affiche les tailles).

**Japonais.** Les titres utilisent `fonts/noto-sans-jp-subset-900.woff2`, un extrait de
Noto Sans CJK JP Black limité aux caractères de `i18n.js`. Si un texte japonais change :

```sh
node -e "global.window={};require('./store/screenshots/generator-v3/i18n.js');const j=window.I18N.ja;require('fs').writeFileSync('/tmp/ja.txt',Object.entries(j).filter(([k])=>!k.startsWith('_')).map(([,v])=>v).join('').replace(/<[^>]+>/g,'')+'0123456789.,!?！？、。…')"
pyftsubset NotoSansCJK-Black.ttc --font-number=0 --text-file=/tmp/ja.txt --flavor=woff2 \
  --layout-features='*' --output-file=store/screenshots/generator-v3/fonts/noto-sans-jp-subset-900.woff2
```

Polices : Sofia Sans Condensed (titres, celle de l'app), Inter (interface), Noto Sans Hebrew,
Arabic et CJK — toutes sous licence OFL.
