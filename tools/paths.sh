# À sourcer : chemins du jeu (JEU_EXE), de Proton (PROTON) et du préfixe Wine (PREFIXE_ANTHEM), lus dans game.conf à la racine du projet s'il existe (relatifs à cette racine, ~ pour le dossier personnel), sinon ceux de Heroic sous $HOME.
racine_projet="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$racine_projet/game.conf" ]] && source "$racine_projet/game.conf"
JEU_EXE="${JEU_EXE:-$HOME/Games/Anthem/Anthem/Anthem.exe}"
PROTON="${PROTON:-$HOME/.config/heroic/tools/proton/GE-Proton-latest}"
PREFIXE_ANTHEM="${PREFIXE_ANTHEM:-$HOME/Games/Heroic/Prefixes/default/Anthem}"
chemin_du_projet() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    "~"/*) printf '%s' "$HOME/${1#"~/"}" ;;
    *) printf '%s' "$racine_projet/$1" ;;
  esac
}
JEU_EXE="$(chemin_du_projet "$JEU_EXE")"
PROTON="$(chemin_du_projet "$PROTON")"
PREFIXE_ANTHEM="$(chemin_du_projet "$PREFIXE_ANTHEM")"
