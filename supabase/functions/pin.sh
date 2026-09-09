#!/usr/bin/env bash
#
# Produit le point d'entrée à déployer quand seule l'**API** de déploiement est disponible.
#
# **Ce n'est pas la façon normale de déployer.** La façon normale est celle du README :
#
#     supabase functions deploy youtube-transcript
#
# Elle envoie les sources telles quelles et demande un jeton personnel (`sbp_…`). Ce script
# existe pour le cas où l'on n'en a pas — une clé de service ouvre l'API de déploiement, pas
# l'API de gestion.
#
# ## Ce que ce script produit, et pourquoi c'est trois lignes
#
# L'API exige que **toutes les dépendances relatives** arrivent avec l'entrée. Un fichier par
# module, c'est deux cents kilo-octets à faire passer. Deno sait importer un module distant, et
# `raw.githubusercontent.com` sert ce dépôt : le point d'entrée est donc un import épinglé sur
# un commit, et le graphe entier se résout depuis le dépôt. La construction inline tout dans
# l'artefact déployé, il ne reste aucun appel à GitHub à l'exécution.
#
# Deux propriétés valent d'être dites, parce que ce sont elles qui ont motivé ce script.
#
# **Le déployé est le relu.** Un commit nomme exactement le code qui tourne : on le retrouve
# avec `git show`. C'est ce que remplaçait l'ancien artefact — un bundle compressé en base64,
# exécuté par `eval` — et il ne le disait pas.
#
# **Une corruption ne peut plus passer inaperçue.** Le 9 septembre 2026, un de ces artefacts a
# été déployé avec un caractère abîmé dans son base64 : `atob` a échoué au chargement, la
# fonction a rendu `WORKER_ERROR` à chaque appel, et l'aperçu YouTube — qui marchait — a cessé
# de répondre. Trois lignes de texte lisible n'ont pas cette classe de panne.
#
# ## Ce qu'il faut avant de s'en servir
#
# Le commit doit être **poussé**, et le dépôt lisible sans jeton. Sinon la construction ne peut
# pas le lire, et il n'y a rien à déployer.
#
#     ./pin.sh                # les quatre fonctions, sur HEAD
#     ./pin.sh <commit>       # sur un autre commit
#
# Après un déploiement, vérifier que la fonction se charge :
#
#     ./smoke.sh youtube-transcript
#
# `--no-lock` sur la vérification n'est pas une négligence : sans lui, `deno.lock` retient les
# empreintes d'un commit, et le fichier changerait à chaque épinglage sans rien dire de plus.
#
set -euo pipefail

cd "$(dirname "$0")"

FUNCTIONS=(generate-course generate-flashcards generate-mock grade-mock explain-selection youtube-transcript)
REPO="adrienmrtn/feymind_flashcards"
COMMIT="${1:-$(git rev-parse HEAD)}"
OUT="dist"

# Un commit qui n'est pas sur le distant ne se lit pas depuis la construction. Le contrôle est
# ici plutôt que dans le README : un artefact qu'on ne peut pas déployer ne vaut pas la peine
# d'être écrit.
if ! git cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
  echo "pin.sh : $COMMIT n'est pas un commit de ce dépôt"
  exit 1
fi
COMMIT="$(git rev-parse "$COMMIT")"

RAW="https://raw.githubusercontent.com/$REPO/$COMMIT/supabase/functions"
if ! curl -fsS -o /dev/null "$RAW/_shared/caller.ts"; then
  echo "pin.sh : $COMMIT n'est pas lisible sur GitHub — pousse-le d'abord"
  exit 1
fi

mkdir -p "$OUT"

for fn in "${FUNCTIONS[@]}"; do
  cat > "$OUT/$fn.pin.ts" <<PIN
// $fn, déployée depuis son commit d'origine.
//
// Écrit par supabase/functions/pin.sh. Ne pas modifier à la main : la seule chose qui
// se règle ici est le commit, et il se règle en relançant le script.
//
// commit $COMMIT
import "$RAW/$fn/index.ts";
PIN

  printf '%-24s %s\n' "$fn" "dist/$fn.pin.ts"
done

cat <<DONE

Épinglé sur $COMMIT.

Le graphe se vérifie sans rien déployer :

    deno check --allow-import --no-lock dist/youtube-transcript.pin.ts
DONE
