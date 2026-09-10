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

# **Le numéro de build ne se décide pas ici.** Une tentative précédente le calculait dans ce
# script, en patchant `CURRENT_PROJECT_VERSION` avant la construction. Elle ne pouvait pas
# marcher, et le rejet d'App Store Connect est revenu à l'identique : Xcode Cloud **impose son
# propre compteur**, qui part de 1 à la première construction du flux et monte d'une unité à
# chaque suivante. C'est ce nombre-là que TestFlight et l'App Store affichent, quoi que dise le
# projet - d'où des builds numérotés 11 pendant que le dépôt annonçait 67.
#
# Ce que le dépôt garde (`CURRENT_PROJECT_VERSION`) ne sert donc qu'aux archives faites à la
# main. Rien ne demande de le monter à chaque lot ; le commit gravé plus bas identifie le
# binaire bien mieux qu'un compteur.
#
# Le seul remède aux collisions - « The bundle version must be higher than the previously
# uploaded version », quand d'anciens téléversements occupent déjà les petits numéros - est
# côté App Store Connect : onglet Xcode Cloud → Réglages → Build Number → Next Build Number.
# Rôle Admin ou App Manager requis. Voir
# https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds

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
