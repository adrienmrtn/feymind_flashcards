#!/bin/sh
#
# **Ce que Xcode Cloud fixe avant de construire : le numéro de build, et le commit.**
#
# Deux choses qu'on ne peut pas décider depuis le dépôt, parce qu'elles dépendent de la
# construction elle-même. Chacune a sa section plus bas.
#
# ## Le commit
#
# Xcode Cloud construit ce qu'on lui donne et l'envoie dans TestFlight, où deux versions se
# ressemblent : `MARKETING_VERSION` ne bouge pas d'un lot à l'autre, et le numéro de build est
# un compteur qui ne dit rien du code. Quand quelqu'un dit « je ne vois pas les changements »,
# personne — ni lui, ni nous — ne peut répondre à la seule question qui compte : **quel commit
# tourne sur ce téléphone ?**
#
# Ce script y répond. Il écrit le commit court dans `Info.plist`, et les Réglages l'affichent
# sous la version. On compare alors deux chaînes de sept caractères au lieu de discuter.
#
# Xcode Cloud lance ce fichier après le clone, avant la résolution des paquets. Hors Xcode
# Cloud, `CI_COMMIT` est absent : la valeur reste `dev`, écrite dans le dépôt, et c'est
# exactement ce qu'on veut voir sur une construction locale.

set -e

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-..}"
PLIST="$ROOT/Micabo/Info.plist"
PBXPROJ="$ROOT/Micabo.xcodeproj/project.pbxproj"

# ---------------------------------------------------------------------------
# **Un numéro de build qui monte tout seul.**
#
# App Store Connect refuse un téléversement dont le numéro de build n'est pas strictement
# supérieur au précédent - « The bundle version must be higher than the previously uploaded
# version ». Tant que ce numéro vivait dans le dépôt, il ne montait qu'à la main : relancer
# un lot, corriger une erreur de compilation, reconstruire la même branche renvoyaient le
# même numéro, et le téléversement était rejeté après vingt minutes de construction.
#
# Xcode Cloud compte déjà ses constructions, et ce compteur ne redescend jamais :
# `CI_BUILD_NUMBER`. On le décale au-dessus du dernier numéro téléversé à la main, et le
# problème disparaît pour de bon. Le dépôt garde sa valeur pour les constructions locales -
# elle ne part plus jamais chez Apple, donc plus personne n'a à y penser.
#
# `BASE` ne bouge que dans un cas : si l'on repart d'un flux Xcode Cloud neuf, où le
# compteur redémarre à 1. Il vaut alors le plus haut numéro déjà téléversé.
# ---------------------------------------------------------------------------
BASE=67

if [ -n "$CI_BUILD_NUMBER" ] && [ -f "$PBXPROJ" ]; then
  BUILD=$((BASE + CI_BUILD_NUMBER))
  sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PBXPROJ"
  echo "Numéro de build : $BUILD (base $BASE + construction Xcode Cloud $CI_BUILD_NUMBER)"
fi

if [ -z "$CI_COMMIT" ]; then
  echo "Pas de CI_COMMIT : rien à graver, le plist garde sa valeur de dépôt."
  exit 0
fi

SHORT=$(echo "$CI_COMMIT" | cut -c1-7)

# `Set` échoue si la clé n'existe pas encore ; on l'ajoute alors. La clé est dans le dépôt,
# donc c'est la première branche qui sert, mais un plist régénéré ne doit pas casser le build.
/usr/libexec/PlistBuddy -c "Set :MicaboCommit $SHORT" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :MicaboCommit string $SHORT" "$PLIST"

echo "Commit gravé dans l'app : $SHORT"
