# Usage : gdb -p PID -batch -x tools/gdb_active_mission.gdb : à poser dès le menu de démarrage ; au lancement d'une mission qui démarre le serveur interne (fin du traitement « se connecter » 0x14a60f760, en 0x14a60f852 avec l'état demandé edx = StartServer 5, choisi par launch_from_hub.py ; un ConnectToServer 0xf, jeu qui rejoint un hôte pair, est seulement noté, de même que le StartServer d'une partie de hub partagé, identifiant [rsi+0x50] du message reconnu par tools/hub_game.py), depuis le hub ou, pour le prologue d'une nouvelle partie, depuis le menu de démarrage, relève les attributs de la dernière demande de partie (SCNA ou TMPA de data/logs/blaze.log : playMode, questId, desiredDifficulty, startPoint), remplace sur place le niveau du LevelSetup du client ([rcx+0x390]) par le niveau racine s'il est autre (levels/Boot/Boot au menu, même longueur), pointe le point par défaut du niveau racine vers le point de lancement de la quête (data/quest_points_PID.json de tools/default_point.py --quetes), écrit aussitôt ces attributs dans GameStartingInfo, puis à chaque entrée d'état de ServerDylanStartup (0x148010f00, rcx = l'objet, GameStartingInfo en +0x18, drapeau « partie démarrée » +0x31 que pose le message GameStarted absent) et à chaque évaluation de la porte de DylanMissionPhaseStartEntity (0x148537da0 : refus si GameStartingInfo.PlayMode [[0x144a92578]] vaut 3 PilotSpace, sinon quête [+4] comparée à celle du scénario), écrit ces valeurs dans GameStartingInfo à la place du message GameStarted du serveur dédié ; une surveillance en écriture sur GameStartingInfo.PlayMode journalise chaque écriture (instruction, adresses de retour de la pile) et rétablit les valeurs de la mission ; journal data/active_mission_PID.txt.
set pagination off
set confirm off
handle SIGSEGV nostop noprint pass
handle SIGBUS nostop noprint pass
handle SIGILL nostop noprint pass
handle SIGFPE nostop noprint pass
handle SIGUSR1 nostop noprint pass
handle SIGUSR2 nostop noprint pass
handle SIGPIPE nostop noprint pass
handle SIGALRM nostop noprint pass
handle SIGQUIT nostop noprint pass
python
import gdb
import json
import re
import struct
import sys
import time

sys.path.insert(0, "tools")
import hub_game

MISSION_CONNECT_STATE = 0x14A60F852
START_SERVER = 5
JOIN_MESSAGE_GAME_ID = 0x50
STARTUP_STATE_ENTRY = 0x148010F00
STARTING_INFO_OFFSET, GAME_STARTED_OFFSET = 0x18, 0x31
GATE_ENTRY = 0x148537DA0
STARTING_INFO_POINTER = 0x144A92578
BLAZE_LOG = "data/logs/blaze.log"
LEVEL_SETUP_NAME = 0x388 + 0x8
ROOT_LEVEL = b"levels/Root/Root"
DEFAULT_POINT = 0x30
IMAGE_START, IMAGE_END = 0x140001000, 0x150000000
STACK_WORDS = 64
STARTING_INFO_ATTRIBUTES = ("playMode", "questId", "desiredDifficulty", "startPoint")
inferior = gdb.selected_inferior()
QUEST_POINTS = f"data/quest_points_{inferior.pid}.json"
LOG = f"data/active_mission_{inferior.pid}.txt"
launched = None


def qword(address):
    return struct.unpack("<Q", bytes(inferior.read_memory(address, 8)))[0]


def starting_info():
    pointer = qword(STARTING_INFO_POINTER)
    return pointer, struct.unpack("<IIII", bytes(inferior.read_memory(pointer, 16)))


def log(text):
    with open(LOG, "a") as handle:
        handle.write(f"{time.strftime('%H:%M:%S')} {text}\n")


def last_matchmaking_attributes():
    with open(BLAZE_LOG, errors="replace") as handle:
        requests = [line for line in handle if line.startswith(("SCNA = ", "TMPA = "))]
    if not requests:
        return None
    values = dict(re.findall(r'"(\w+)": générique\("(\d+)"\)', requests[-1]))
    if not all(name in values for name in STARTING_INFO_ATTRIBUTES):
        return None
    return tuple(int(values[name]) for name in STARTING_INFO_ATTRIBUTES)


def use_root_level(client):
    pointer = qword(client + LEVEL_SETUP_NAME)
    level = bytes(inferior.read_memory(pointer, 64)).split(b"\0")[0]
    if level.lower() == ROOT_LEVEL.lower():
        return
    if len(level) != len(ROOT_LEVEL):
        log(f"  niveau {level!r} laissé : longueur différente de {ROOT_LEVEL!r}")
        return
    inferior.write_memory(pointer, ROOT_LEVEL)
    log(f"  niveau du client {pointer:#x} {level!r} -> {ROOT_LEVEL!r}")


def use_quest_start_point(quest):
    try:
        table = json.load(open(QUEST_POINTS))
    except (OSError, ValueError) as error:
        log(f"  point de lancement non posé : {error}")
        return
    point = table["quetes"].get(str(quest))
    if point is None:
        log(f"  quête {quest} sans point de lancement connu : point par défaut laissé")
        return
    for component in table["composants"]:
        inferior.write_memory(component + DEFAULT_POINT, struct.pack("<QQ", point["chaine"], point["chaine"]))
    log(f"  point par défaut -> {point['point']} ({point['nom']})")


class MissionConnect(gdb.Breakpoint):
    def __init__(self):
        super().__init__(f"*{MISSION_CONNECT_STATE:#x}", type=gdb.BP_HARDWARE_BREAKPOINT)

    def stop(self):
        global launched
        state = int(gdb.parse_and_eval("$edx")) & 0xFFFFFFFF
        if state != START_SERVER:
            log(f"connexion à un serveur (état {state:#x}) : serveur interne non démarré, rien n'est posé")
            return False
        game = qword((int(gdb.parse_and_eval("$rsi")) & 0xFFFFFFFFFFFFFFFF) + JOIN_MESSAGE_GAME_ID)
        if hub_game.is_hub_game(game):
            log(f"hub partagé : partie {game}, hub rechargé en hôte pair, rien n'est posé")
            return False
        launched = last_matchmaking_attributes()
        log(f"lancement de mission : GameStartingInfo à poser {launched}")
        use_root_level(int(gdb.parse_and_eval("$rcx")) & 0xFFFFFFFFFFFFFFFF)
        if launched is not None:
            use_quest_start_point(launched[1])
            pointer, values = starting_info()
            inferior.write_memory(pointer, struct.pack("<IIII", *launched))
            log(f"  GameStartingInfo {pointer:#x} {values} -> {launched}")
        return False


class StartupState(gdb.Breakpoint):
    def __init__(self):
        super().__init__(f"*{STARTUP_STATE_ENTRY:#x}", type=gdb.BP_HARDWARE_BREAKPOINT)

    def stop(self):
        if launched is None:
            return False
        startup = int(gdb.parse_and_eval("$rcx")) & 0xFFFFFFFFFFFFFFFF
        state = int(gdb.parse_and_eval("$edx")) & 0xFFFFFFFF
        values = struct.unpack("<IIII", bytes(inferior.read_memory(startup + STARTING_INFO_OFFSET, 16)))
        started = bytes(inferior.read_memory(startup + GAME_STARTED_OFFSET, 1))[0]
        inferior.write_memory(startup + STARTING_INFO_OFFSET, struct.pack("<IIII", *launched))
        inferior.write_memory(startup + GAME_STARTED_OFFSET, b"\x01")
        log(f"état de démarrage {state} : ServerDylanStartup {startup:#x} GameStartingInfo {values} démarrée {started}")
        return False


class MissionGate(gdb.Breakpoint):
    def __init__(self):
        super().__init__(f"*{GATE_ENTRY:#x}", type=gdb.BP_HARDWARE_BREAKPOINT)

    def stop(self):
        if launched is None:
            return False
        pointer, values = starting_info()
        if values != launched:
            inferior.write_memory(pointer, struct.pack("<IIII", *launched))
            log(f"porte : GameStartingInfo {pointer:#x} {values} -> {launched}")
        return False


class PlayModeWrite(gdb.Breakpoint):
    def __init__(self, address):
        super().__init__(f"*(int*){address:#x}", type=gdb.BP_WATCHPOINT, wp_class=gdb.WP_WRITE)

    def stop(self):
        if launched is None:
            return False
        pointer, values = starting_info()
        stack = struct.unpack(f"<{STACK_WORDS}Q", bytes(inferior.read_memory(int(gdb.parse_and_eval("$rsp")) & 0xFFFFFFFFFFFFFFFF, 8 * STACK_WORDS)))
        returns = " ".join(f"{word:#x}" for word in stack if IMAGE_START <= word < IMAGE_END)
        log(f"écriture de PlayMode : {values} après {int(gdb.parse_and_eval('$pc')):#x}, pile {returns}")
        if values != launched:
            inferior.write_memory(pointer, struct.pack("<IIII", *launched))
        return False


log(f"attaché, GameStartingInfo {starting_info()}")
PlayModeWrite(starting_info()[0])
MissionConnect()
StartupState()
MissionGate()
end
continue
