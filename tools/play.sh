#!/bin/bash
# Usage : tools/play.sh : lanceur simplifié, comme le mode « Local » du lanceur : compile les services, pointe /etc/hosts vers ce PC (sudo si besoin), lance services et correctifs, puis le jeu (chemins de tools/paths.sh) ; tout s'arrête à la fermeture du jeu ou par Ctrl+C ; journaux dans data/logs/.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
journaux="$racine/data/logs"
redirector=spring18.gosredirector.ea.com
cd "$racine"
mkdir -p "$journaux"

adresse="$(ip -4 route get 1.1.1.1 | grep -o 'src [0-9.]*' | cut -d' ' -f2)"
[[ -n "$adresse" ]] || { echo "adresse réseau de ce PC introuvable" >&2; exit 1; }
if ! grep -qE "^$adresse[[:space:]]+$redirector\$" /etc/hosts; then
  echo "/etc/hosts : $redirector vers $adresse (mot de passe administrateur)"
  { grep -v "$redirector" /etc/hosts; echo "$adresse $redirector"; } > "$journaux/hosts"
  sudo tee /etc/hosts < "$journaux/hosts" > /dev/null
fi

attendre() {
  local journal="$1" message="$2"
  for _ in $(seq 1 300); do
    grep -q "$message" "$journal" 2>/dev/null && return
    sleep 1
  done
  echo "pas de « $message » dans $journal après 5 min" >&2
  exit 1
}

echo "compilation des services"
cargo build -q --bins
trap 'kill 0' EXIT
BINAIRES=target/debug tools/central_server.sh "$adresse" > "$journaux/play_services.log" 2>&1 &
attendre "$journaux/play_services.log" "serveur central sur"
SERVEUR_CENTRAL="$adresse" tools/start.sh > "$journaux/play_patches.log" 2>&1 &
attendre "$journaux/play_patches.log" "services lancés"
echo "services et correctifs prêts, lancement du jeu"
tools/launch_game.sh
