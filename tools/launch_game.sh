#!/bin/bash
# Usage : [PREFIXE_JEU=dossier] [JOURNAL_JEU=fichier] [GARDER_PREMIER_LANCEMENT=1] [FERMETURE_DOUCE=1][WINEDEBUG_JEU=canaux] [JEU_ARGS="-Groupe.Champ valeur"] [TOUCHES_JEU="f space"] [GARDER_CONSOLE=1] tools/launch_game.sh [durée_en_secondes] : relance Anthem sous Proton (chemins de tools/paths.sh), démarre l'émulateur LSX hors ligne (-alwaysoffline, sans sa fenêtre de choix), réduit la console de FINRACHAOS.dll, puis le laisse tourner jusqu'à sa fermeture, ou l'arrête au bout de la durée donnée.
set -uo pipefail

duree="${1:-}"
racine="$(cd "$(dirname "$0")/.." && pwd)"
source "$racine/tools/paths.sh"
prefixe="${PREFIXE_JEU:-$PREFIXE_ANTHEM}"
journal="${JOURNAL_JEU:-$racine/data/crash_seh.log}"
proton="$PROTON"
jeu="$JEU_EXE"

WINEPREFIX="$prefixe/pfx" "$proton/files/bin/wineserver" -k 2>/dev/null
sleep 2
[[ -z "${GARDER_PREMIER_LANCEMENT:-}" ]] && python3 -I "$racine/tools/first_launch_done.py" "$prefixe/pfx/drive_c/users/steamuser/Documents/BioWare/Anthem/settings/ProfileOptions"

PROTON_DISABLE_NVAPI=1 STEAM_COMPAT_DATA_PATH="$prefixe" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam" \
  WINEDEBUG="${WINEDEBUG_JEU:--all,+seh,err+all}" "$proton/proton" run "$jeu" -alwaysoffline ${JEU_ARGS:-} > "$journal" 2>&1 &

reduire_console() {
  local console
  for _ in $(seq 1 120); do
    console=$(xdotool search --name 'Anthem\\Anthem\.exe$' 2>/dev/null | head -1)
    if [[ -n "$console" ]]; then
      xdotool windowminimize "$console"
      return
    fi
    sleep 1
  done
}
[[ -z "${GARDER_CONSOLE:-}" ]] && reduire_console &

# Options de premier lancement (F) puis écran titre (Espace) : touches envoyées à la fenêtre du jeu.
sleep "${TOUCHES_DELAI:-70}"
for touche in ${TOUCHES_JEU-f space}; do
  fenetre_jeu=$(xdotool search --name "^Anthem" 2>/dev/null | tail -1)
  [[ -n "$fenetre_jeu" ]] && xdotool key --window "$fenetre_jeu" "$touche"
  sleep 8
done

if [[ -z "$duree" ]]; then
  WINEPREFIX="$prefixe/pfx" "$proton/files/bin/wineserver" -w
  echo "jeu fermé"
  exit 0
fi
sleep "$duree"
if [[ -n "${FERMETURE_DOUCE:-}" ]]; then
  for exe in Anthem.exe Dylan.Main_win64_retail.exe; do
    WINEPREFIX="$prefixe/pfx" "$proton/files/bin/wine" taskkill /im "$exe" > /dev/null 2>&1
  done
  sleep 45
fi
WINEPREFIX="$prefixe/pfx" "$proton/files/bin/wineserver" -k 2>/dev/null
echo "jeu arrêté après ${duree} s"
