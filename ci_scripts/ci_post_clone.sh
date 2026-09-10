#!/bin/sh
#
# **Graver le commit dans l'app.**
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

PLIST="${CI_PRIMARY_REPOSITORY_PATH:-..}/Micabo/Info.plist"

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
