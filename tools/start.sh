#!/bin/bash
# Usage : tools/start.sh : compile et lance redirector, blaze et bigs (missions annoncées sur un serveur dédié, BLAZE_SERVEUR_MISSION_ID, 2000000 par défaut, vide pour aucun), puis à chaque lancement du jeu corrige FINRACHAOS.dll en mémoire et applique les correctifs des missions sur le serveur interne (tools/auto_patches.py) ; journaux dans data/logs/, Ctrl+C arrête tout. SERVEUR_CENTRAL=IP : services lancés ailleurs (tools/central_server.sh), seuls les correctifs des jeux tournent ici. MISSION_PAIR=1 : redirection pair (launch_from_hub.py --pair, missions Blaze en pair BLAZE_MISSION_PAIR=1 imposées) : chaque jeu démarre son serveur interne en hôte pair s'il est hôte de topologie de la mission Blaze (il l'a lancée), sinon rejoint l'hôte. SECOND_JEU=1 : MISSION_PAIR=1, Blaze sur 10.200.0.1 et second BIGS (persona 1001, port 8081) pour le second jeu d'tools/second_jeu.sh, qui reçoit exactement les mêmes correctifs que le premier (journal patches_second.log) : chacun peut lancer une mission seul ou rejoindre celle de l'autre. HUB_PARTAGE=1 : hub partagé de l'escouade (MISSION_PAIR=1 ; pour le Blaze local, BLAZE_HUB_PARTAGE=1 et BLAZE_ESCOUADE_AUTO=1), ouvert à la main par tools/hub_partage.sh.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
journaux="$racine/data/logs"
cd "$racine"
mkdir -p "$journaux"
exec 9> "$journaux/start.lock"
if ! flock -n 9; then
  echo "tools/start.sh tourne déjà : arrête-le avant d'en lancer un autre" >&2
  exit 1
fi

serveur="${SERVEUR_CENTRAL:-127.0.0.1}"
if ! getent hosts spring18.gosredirector.ea.com | grep -q "$serveur"; then
  echo "spring18.gosredirector.ea.com ne pointe pas vers $serveur : corrige la ligne dans /etc/hosts" >&2
  exit 1
fi

[[ -z "${SERVEUR_CENTRAL:-}" ]] && cargo build -q --bins
if [[ -n "${SECOND_JEU:-}" ]]; then
  ip netns list | grep -qw anthem2 || { echo "lance d'abord : tools/second_jeu.sh reseau" >&2; exit 1; }
  export MISSION_PAIR=1 BLAZE_MISSION_PAIR=1 BLAZE_HOST=10.200.0.1 BLAZE_IP=10.200.0.1
  export BLAZE_PERSONAS="10.200.0.2=1001:Joueur 2:http://10.200.0.1:8081"
  mkdir -p data/saves/1001
fi
if [[ "${HUB_PARTAGE:-}" == 1 ]]; then export MISSION_PAIR=1 BLAZE_HUB_PARTAGE=1 BLAZE_ESCOUADE_AUTO=1; fi
if [[ "${MISSION_PAIR:-}" == 1 ]]; then export BLAZE_MISSION_PAIR=1; fi
export BLAZE_SERVEUR_MISSION_ID="${BLAZE_SERVEUR_MISSION_ID-2000000}"
export JOUEUR_NOM="${JOUEUR_NOM-Joueur 1}"
trap 'kill 0' EXIT
if [[ -n "${SERVEUR_CENTRAL:-}" ]]; then
  export MISSION_PAIR=1
else
  for service in redirector blaze bigs; do
    "./target/debug/$service" > "$journaux/$service.log" 2>&1 &
  done
fi
if [[ -n "${SECOND_JEU:-}" && -z "${SERVEUR_CENTRAL:-}" ]]; then
  BIGS_PORT=8081 JOUEUR_ID=1001 JOUEUR_NOM="Joueur 2" BIGS_ETAT=data/saves/state_1001.json \
    BIGS_SAUVEGARDES=data/saves/1001 ./target/debug/bigs > "$journaux/bigs_1001.log" 2>&1 &
fi
reseau_machine="$(readlink /proc/self/ns/net)"
corriger_mod_a_chaque_lancement() {
  local corriges=" " suivis=" "
  while true; do
    local jeu
    for jeu in $(pgrep -f '^X:.*Anthem\.exe' || true); do
      if [[ "$suivis" != *" $jeu "* ]]; then
        if [[ "$(readlink "/proc/$jeu/ns/net" 2>/dev/null)" == "$reseau_machine" ]]; then
          python3 -I "$racine/tools/auto_patches.py" "$jeu" >> "$journaux/patches.log" 2>&1 &
        else
          python3 -I "$racine/tools/auto_patches.py" "$jeu" >> "$journaux/patches_second.log" 2>&1 &
        fi
        suivis+="$jeu "
      fi
      if [[ "$corriges" != *" $jeu "* ]] && grep -q FINRACHAOS "/proc/$jeu/maps" 2>/dev/null; then
        if python3 -I "$racine/tools/patch_finrachaos.py" "$jeu" --appliquer >> "$journaux/finrachaos.log" 2>&1; then
          corriges+="$jeu "
        fi
      fi
    done
    sleep 1
  done
}
corriger_mod_a_chaque_lancement &

sleep 1
ss -tlnH | grep -E ":(42230|10041|8080) " || true
echo "services lancés, journaux dans $journaux ; lance le jeu (FINRACHAOS.dll sera corrigé automatiquement)"
wait
