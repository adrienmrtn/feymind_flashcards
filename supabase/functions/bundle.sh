#!/usr/bin/env bash
#
# Regroupe chaque Edge Function en un seul fichier, et produit l'artefact déployable.
#
# **Ce n'est pas la façon normale de déployer.** La façon normale est celle du README :
#
#     supabase functions deploy generate-course
#
# Elle envoie les sources telles quelles, avec leurs modules partagés, et c'est mieux — le code
# qui tourne est alors exactement celui qu'on relit. Ce script existe pour le cas où seule l'API
# de déploiement est disponible : elle exige que **toutes les dépendances relatives** soient
# fournies avec l'entrée, et un regroupement les inline en un fichier qui se passe en une fois.
#
# L'import `jsr:…/edge-runtime.d.ts` est retiré avant le regroupement : il n'existe que pour les
# types, et `Deno.serve` est global dans l'exécution edge.
#
# Le déployé reste donc reproductible depuis le dépôt, par cette commande et pas autrement.
#
#     ./bundle.sh            # produit dist/<fonction>.js et dist/<fonction>.deploy.ts
#
# ## Pourquoi ce script produit aussi l'enveloppe
#
# Un bundle de 50 Ko ne passe pas en clair par l'API de déploiement : il faut le compresser et
# le décompresser au chargement. Cette enveloppe était fabriquée à la main, et le 1er septembre
# 2026 une version fabriquée ainsi a été déployée sans pouvoir se charger : la fonction rendait
# `WORKER_ERROR` à **chaque** appel, y compris ceux qui auraient dû répondre 400 avant de lire
# la moindre variable. Une fonction qui ne charge pas ne laisse aucune trace utile, et l'app
# comme le site n'en voient qu'un « non-2xx ».
#
# L'enveloppe est donc générée ici, jamais recopiée, et les trois contrôles ci-dessous refusent
# de produire un artefact qui ne se chargerait pas.
#
set -euo pipefail

cd "$(dirname "$0")"

FUNCTIONS=(generate-course generate-flashcards explain-selection youtube-transcript)
WORK="$(mktemp -d)"
OUT="dist"

mkdir -p "$OUT"
cp -r _shared "$WORK/"

for fn in "${FUNCTIONS[@]}"; do
  mkdir -p "$WORK/$fn"
  sed '/jsr:@supabase\/functions-js\/edge-runtime.d.ts/d' "$fn/index.ts" > "$WORK/$fn/index.ts"
  [ -f "$fn/prompt.ts" ] && cp "$fn/prompt.ts" "$WORK/$fn/"

  npx --yes esbuild "$WORK/$fn/index.ts" \
    --bundle --format=esm --platform=neutral --target=es2022 \
    --legal-comments=none --minify \
    --outfile="$OUT/$fn.js"

  # Deux contrôles qui valent mieux qu'une inspection à l'œil : sans `Deno.serve` la fonction ne
  # répond à rien, et un `Deno.env` perdu lui retire sa clé.
  grep -q "Deno.serve" "$OUT/$fn.js" || { echo "$fn : Deno.serve absent du regroupement"; exit 1; }
  grep -q "Deno.env" "$OUT/$fn.js" || { echo "$fn : Deno.env absent du regroupement"; exit 1; }

  # Le troisième, et c'est celui qui manquait. L'enveloppe exécute le bundle par `eval`, donc en
  # script et non en module : un seul `import` ou `export` résiduel le rend inexécutable, et la
  # fonction ne se charge plus du tout. `--bundle` les inline tous, sauf ce qui a été déclaré
  # externe — d'où ce garde-fou plutôt qu'une confiance dans les options passées plus haut.
  if grep -qE '(^|[;}[:space:]])(import|export)[[:space:]]*[{"'"'"']' "$OUT/$fn.js"; then
    echo "$fn : le regroupement garde un import ou un export, il ne pourra pas se charger"
    exit 1
  fi

  # `-n` : ni nom de fichier ni horodatage dans l'en-tête gzip. L'artefact est alors identique
  # d'une machine à l'autre pour une même source, donc comparable à ce qui est déployé.
  payload="$(gzip -n -9 -c "$OUT/$fn.js" | base64 | tr -d '\n')"
  digest="$(shasum -a 256 "$OUT/$fn.js" | cut -d' ' -f1)"

  cat > "$OUT/$fn.deploy.ts" <<DEPLOY
// $fn, regroupé et compressé par supabase/functions/bundle.sh.
//
// Ne pas modifier à la main : regénérer avec \`./bundle.sh\`. Le CRC du gzip refuse un
// payload abîmé, et la fonction rendrait alors WORKER_ERROR à chaque appel.
//
// sha256 du bundle en clair : $digest
const PAYLOAD =
  "$payload";

const bytes = Uint8Array.from(atob(PAYLOAD), (c) => c.charCodeAt(0));
const source = await new Response(
  new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip")),
).text();

// Le bundle n'a ni import ni export : \`bundle.sh\` le vérifie avant d'écrire ce fichier.
(0, eval)(source);
DEPLOY

  printf '%-24s %6.1f Ko  ->  %6.1f Ko compressé\n' "$fn" \
    "$(awk "BEGIN{printf \"%.1f\", $(wc -c < "$OUT/$fn.js")/1024}")" \
    "$(awk "BEGIN{printf \"%.1f\", ${#payload}/1024}")"
done

rm -rf "$WORK"

cat <<'DONE'

dist/<fonction>.js         le regroupement, lisible
dist/<fonction>.deploy.ts  ce qui se déploie quand seule l'API est disponible

Après un déploiement, vérifier que la fonction se charge :

    ./smoke.sh generate-course
DONE
