#!/bin/bash
# Usage : tools/central_server.sh IP_SERVEUR [IP=ID:NOM ...] : lance redirector, Blaze et un BIGS par joueur sur une machine dédiée (missions en pair hébergé) ; le joueur 1000 « Joueur 1 » est celui de toute adresse non déclarée, BIGS 8080, data/saves/state.json et ses sauvegardes dans data/saves/1000 ; chaque joueur déclaré a son BIGS sur 8080 + rang, data/saves/state_ID.json, créé par BIGS à partir du tutoriel terminé s'il manque ; journaux dans data/logs/, Ctrl+C arrête tout ; BINAIRES=dossier (bin par défaut, target/debug pour un serveur local).
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
journaux="$racine/data/logs"
cd "$racine"
mkdir -p "$journaux"

for fichier in "${TLS_CERT:-data/certs/test.crt}" "${TLS_KEY:-data/certs/test.key}"; do
  [[ -f "$fichier" ]] || { echo "certificat absent ($fichier) : commande pour le générer dans README.md" >&2; exit 1; }
done

ip="${1:?IP du serveur attendue}"
shift
binaires="${BINAIRES:-bin}"
export BLAZE_IP="$ip" BLAZE_HOST="$ip" BLAZE_MISSION_PAIR=1 BLAZE_SERVEUR_MISSION_ID="${BLAZE_SERVEUR_MISSION_ID-2000000}"
export JOUEUR_NOM="${JOUEUR_NOM-Joueur 1}" BIGS_URL="http://$ip:8080"
export BIGS_SAUVEGARDES="${BIGS_SAUVEGARDES-data/saves/1000}"
mkdir -p "$BIGS_SAUVEGARDES"

trap 'kill 0' EXIT
personas=""
rang=1
for joueur in "$@"; do
  adresse="${joueur%%=*}" reste="${joueur#*=}"
  id="${reste%%:*}" nom="${reste#*:}"
  port=$((8080 + rang))
  personas+="$adresse=$id:$nom:http://$ip:$port;"
  mkdir -p "data/saves/$id"
  BIGS_PORT="$port" JOUEUR_ID="$id" JOUEUR_NOM="$nom" BIGS_ETAT="data/saves/state_$id.json" \
    BIGS_SAUVEGARDES="data/saves/$id" "./$binaires/bigs" > "$journaux/bigs_$id.log" 2>&1 &
  rang=$((rang + 1))
done
export BLAZE_PERSONAS="$personas"
for service in redirector blaze bigs; do
  "./$binaires/$service" > "$journaux/$service.log" 2>&1 &
done
sleep 1
ss -tlnH | grep -E ":(42230|10041|80[0-9][0-9]) " || true
echo "serveur central sur $ip, joueurs déclarés : ${personas:-aucun}"
wait
