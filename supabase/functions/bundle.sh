#!/usr/bin/env bash
#
# Regroupe chaque Edge Function en un seul fichier.
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
#     ./bundle.sh            # produit dist/<fonction>.js
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

  printf '%-24s %6.1f Ko\n' "$fn" "$(awk "BEGIN{printf \"%.1f\", $(wc -c < "$OUT/$fn.js")/1024}")"
done

rm -rf "$WORK"
