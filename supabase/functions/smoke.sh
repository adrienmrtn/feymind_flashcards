#!/usr/bin/env bash
#
# Est-ce que la fonction déployée **se charge** ?
#
# Ce n'est pas un test de son contenu : c'est le contrôle qui manquait. Une Edge Function dont
# le module échoue au chargement rend `WORKER_ERROR` à chaque appel, avant d'entrer dans le
# moindre `try`. Côté produit, l'app dit « l'analyse du document a échoué » et le site
# « Edge Function returned a non-2xx status code » : deux messages qui ressemblent à une panne
# du modèle alors que rien n'a jamais tourné.
#
# La sonde envoie donc un corps volontairement trop court. Une fonction saine le refuse en 400,
# avec son propre message. Une fonction qui ne charge pas rend 500 et `WORKER_ERROR`, et c'est
# exactement ce qu'on veut voir échouer ici.
#
#     ./smoke.sh                      # les quatre fonctions
#     ./smoke.sh generate-course      # une seule
#
# La clé `anon` est publique par nature (voir web/lib/config.ts) : elle passe `verify_jwt` et
# n'ouvre rien de plus qu'un visiteur anonyme.
#
set -uo pipefail

URL="${SUPABASE_URL:-https://khuzodsrznanzhwlbjbx.supabase.co}"
KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtodXpvZHNyem5hbnpod2xiamJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5NDg1MzIsImV4cCI6MjEwMTUyNDUzMn0.-PBadJI6rdYgoHisEfP54CN126IiT9DNIXR4J-vNYLw}"

FUNCTIONS=("$@")
if [ ${#FUNCTIONS[@]} -eq 0 ]; then
  FUNCTIONS=(generate-course generate-flashcards explain-selection youtube-transcript)
fi

failed=0

for fn in "${FUNCTIONS[@]}"; do
  body="$(curl -s -X POST "$URL/functions/v1/$fn" \
    -H "Authorization: Bearer $KEY" \
    -H "apikey: $KEY" \
    -H "Content-Type: application/json" \
    -d '{}' 2>/dev/null)"

  if printf '%s' "$body" | grep -q "WORKER_ERROR"; then
    printf '%-24s NE SE CHARGE PAS\n' "$fn"
    printf '%s\n' "  $body"
    failed=1
  else
    printf '%-24s se charge\n' "$fn"
  fi
done

if [ "$failed" -ne 0 ]; then
  cat <<'HINT'

Une fonction qui ne se charge pas se redéploie depuis les sources :

    supabase functions deploy <fonction>

Si seule l'API de déploiement est disponible, regénérer l'artefact avant de l'envoyer :

    ./bundle.sh    puis déployer dist/<fonction>.deploy.ts

HINT
  exit 1
fi
