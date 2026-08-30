# Captures App Store (goldie)

Cinq screenshots 6.9″ (1320 × 2868) et un aperçu vidéo, produits avec
[goldie](https://github.com/kacperkapusciak/goldie).

Les flux argent sont dans `.argent/flows/store-*.yaml`. Le catalogue de
vitrine (`ScreenshotSeed`) remplit Réviser, les fiches, les cartes et
deux examens — l'app part autrement vide.

## Sur un Mac, depuis le simulateur

Il faut Xcode, un iPhone 16 Pro Max (ou 17 Pro Max), Node 20+, ffmpeg.

```bash
# 1. Build Release pour le simulateur
xcodebuild -scheme Micabo -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -derivedDataPath /tmp/micabo-goldie build

export MICABO_APP=/tmp/micabo-goldie/Build/Products/Release-iphonesimulator/Micabo.app
export GOLDIE_CONFIG="$(pwd)/goldie/goldie.config.ts"

# 2. Drapeau de vitrine dans le simulateur (survit à la réinstallation)
./goldie/prepare.sh

# 3. Capturer, cadrer, vérifier
npx -y goldie@0 doctor
npx -y goldie@0 capture
npx -y goldie@0 frame
npx -y goldie@0 manifest
npx -y goldie@0 studio --no-open   # http://localhost:4321
```

Sans simulateur, `goldie/mock/` recrée les cinq écrans et les cadre aux
mêmes dimensions. Les PNG prêts à envoyer sont dans `goldie/screenshots/`.

```bash
# depuis goldie/
python3 -m http.server 8766
# autre terminal
cd mock && npm i playwright && npx playwright install chromium
MOCK_ORIGIN=http://127.0.0.1:8766 node capture.mjs
```

## Scènes

| Id | Écran | Accroche |
| --- | --- | --- |
| `today` | Réviser | Juste avant l'oubli |
| `sheet` | Fiche | Le cours, déjà fiché |
| `study` | Session | Tu te souviens, ou pas |
| `exam` | Examens | Le jour J commande |
| `courses` | Cours | PDF, photo ou vidéo |
