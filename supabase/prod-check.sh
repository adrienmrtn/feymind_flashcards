#!/usr/bin/env bash
#
# **La prod a-t-elle tout ce qu'attend l'app ?** Les migrations de la refonte « parcours » et
# la fonction `generate-lesson`, vérifiées de l'extérieur, avec la seule clé `anon` (publique
# par nature, voir web/lib/config.ts). Rien n'est écrit : les colonnes et la table se lisent
# avec `limit=0`, les fonctions SQL sont appelées par un visiteur anonyme, qui doit être
# refusé (`42501`) — c'est la preuve qu'elles existent, avec leur signature, et qu'elles sont
# bien fermées.
#
#     ./supabase/prod-check.sh
#
# Le workflow « Prod » le lance à la demande (Actions → Prod → Run workflow).
#
set -uo pipefail

URL="${SUPABASE_URL:-https://khuzodsrznanzhwlbjbx.supabase.co}"
KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtodXpvZHNyem5hbnpod2xiamJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5NDg1MzIsImV4cCI6MjEwMTUyNDUzMn0.-PBadJI6rdYgoHisEfP54CN126IiT9DNIXR4J-vNYLw}"
ZERO="00000000-0000-0000-0000-000000000000"

failed=0
status=""
body=""

call() {
  local out
  out="$(curl -sS -m 30 -w $'\n%{http_code}' "$@" 2>&1)"
  status="${out##*$'\n'}"
  body="${out%$'\n'*}"
}

anon() {
  call -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" "$@"
}

report() {
  local verdict="$1" label="$2"
  printf '%-4s %-52s HTTP %s  %s\n' "$verdict" "$label" "$status" "$(printf '%s' "$body" | tr -d '\n' | cut -c1-160)"
  [ "$verdict" = "OK" ] || failed=1
}

# Une colonne lue : 200 (lisible) ou 401/403 (fermée à l'anonyme) prouvent qu'elle existe ;
# une colonne absente rend 400 et `42703`.
columns() {
  local table="$1" select="$2"
  anon "$URL/rest/v1/$table?select=$select&limit=0"
  case "$status" in
    200|401|403) report OK "$table : $select" ;;
    *) report NON "$table : $select" ;;
  esac
}

# Une fonction SQL appelée par l'anonyme : refusée (`42501`) = présente et fermée.
closed_rpc() {
  local label="$1" name="$2" args="$3"
  anon -X POST "$URL/rest/v1/rpc/$name" -d "$args"
  if printf '%s' "$body" | grep -q '"42501"'; then
    report OK "$label"
  elif printf '%s' "$body" | grep -q 'PGRST203'; then
    report NON "$label (deux versions : l'ancienne n'est pas retirée)"
  elif printf '%s' "$body" | grep -q 'PGRST202'; then
    report NON "$label (introuvable)"
  else
    report NON "$label (ouverte à l'anonyme ?)"
  fi
}

echo "Prod : $URL"
echo
echo "— Migration 1 : lesson_paths"
anon "$URL/rest/v1/courses?select=zz_colonne_absente&limit=0"
if [ "$status" = "400" ]; then report OK "contrôle : une colonne absente est bien vue"; else report NON "contrôle : une colonne absente est bien vue"; fi
columns courses "path,progress,tone,icon,last_opened_at"
columns chapters "icon,notes,quiz,status"

echo
echo "— Migration 2 : lesson_generations"
anon "$URL/rest/v1/lesson_generations?select=lesson_id,user_id,kind,source,themes,theme_calls,created_at&limit=0"
case "$status" in
  200|401|403) report OK "table lesson_generations" ;;
  *) report NON "table lesson_generations" ;;
esac
closed_rpc "is_pro(p_user)" is_pro "{\"p_user\":\"$ZERO\"}"
closed_rpc "lesson_theme_call(p_user, p_lesson)" lesson_theme_call "{\"p_user\":\"$ZERO\",\"p_lesson\":\"$ZERO\"}"

echo
echo "— Migration 3 : lesson_onboarding"
closed_rpc "begin_lesson(…, p_onboarding)" begin_lesson \
  "{\"p_user\":\"$ZERO\",\"p_lesson\":\"$ZERO\",\"p_kind\":\"convert\",\"p_source\":\"text\",\"p_themes\":0,\"p_onboarding\":false}"
closed_rpc "begin_lesson à cinq arguments : une seule candidate" begin_lesson \
  "{\"p_user\":\"$ZERO\",\"p_lesson\":\"$ZERO\",\"p_kind\":\"convert\",\"p_source\":\"text\",\"p_themes\":0}"

echo
echo "— Fonction generate-lesson"
call -X POST "$URL/functions/v1/generate-lesson" -H "Content-Type: application/json" -d '{}'
if [ "$status" = "401" ]; then report OK "sans jeton : refusée (Verify JWT)"; else report NON "sans jeton : refusée (Verify JWT)"; fi
# Un corps vide n'appelle aucun modèle : le code de la leçon répond « Étape inconnue ».
anon -X POST "$URL/functions/v1/generate-lesson" -d '{}'
if [ "$status" = "400" ] && printf '%s' "$body" | grep -q "tape inconnue"; then
  report OK "se charge, et c'est bien le code de la leçon"
else
  report NON "se charge, et c'est bien le code de la leçon"
fi

echo
echo "— Les autres fonctions se chargent toujours"
for fn in generate-course generate-flashcards generate-mock grade-mock explain-selection youtube-transcript mika-chat; do
  anon -X POST "$URL/functions/v1/$fn" -d '{}'
  if [ "$status" = "404" ] || printf '%s' "$body" | grep -q -E "WORKER_ERROR|BOOT_ERROR"; then
    report NON "$fn"
  else
    report OK "$fn"
  fi
done

echo
if [ "$failed" -ne 0 ]; then
  echo "Au moins une vérification a échoué (NON ci-dessus). Ordre de déploiement : docs/refonte-parcours.md § 16."
  exit 1
fi
echo "Tout est en place."
