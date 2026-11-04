#!/bin/bash
# Usage : tools/stop_game.sh jeu1|jeu2 : arrête le jeu (préfixe de tools/paths.sh) ou le second jeu (même préfixe suivi de 2, tools/second_jeu.sh).
set -euo pipefail
source "$(dirname "$0")/paths.sh"
case "${1:-}" in
  jeu1) prefixe="$PREFIXE_ANTHEM" ;;
  jeu2) prefixe="${PREFIXE_ANTHEM}2" ;;
  *) sed -n 2p "$0" >&2; exit 1 ;;
esac
WINEPREFIX="$prefixe/pfx" "$PROTON/files/bin/wineserver" -k
