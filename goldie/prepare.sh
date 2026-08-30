#!/usr/bin/env bash
# Pose le drapeau de vitrine dans le simulateur, avant `goldie capture`.
# Goldie réinstalle l'app : le fichier vit dans /tmp du simulateur, pas dans
# le container, donc il survit à la réinstallation.
set -euo pipefail

DEVICE_NAME="${GOLDIE_SIMULATOR:-iPhone 16 Pro Max}"

udid="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" '
  $0 ~ name {
    if (match($0, /\(([A-F0-9-]+)\)/, m)) { print m[1]; exit }
  }
')"

if [[ -z "${udid}" ]]; then
  echo "Aucun simulateur « ${DEVICE_NAME} » disponible." >&2
  echo "Règle GOLDIE_SIMULATOR sur le nom exact (xcrun simctl list devices)." >&2
  exit 1
fi

xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
xcrun simctl spawn "${udid}" sh -c 'printf 1 > /tmp/micabo.goldie.seed'
echo "Drapeau posé sur ${DEVICE_NAME} (${udid})."
