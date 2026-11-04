"""Usage : python3 -I player_list.py PID {poser|etat} : liste des joueurs du serveur interne, lue dans ses structures (docs/ai-enemy-summary.md, « Players on the server »). Contexte serveur [0x1446ceca0], ServerPeer [contexte+0xb8] (table 0x143b65598), connexions [ServerPeer+0x45a8..+0x45b0] (ServerConnection, table 0x143a574e8), fiches de joueurs de chaque connexion [connexion+0xa90..+0xa98] dont [fiche+0xf8] est le ServerPlayer (lu en 0x1407b9a70 et 0x1408dc7ea), personnage [ServerPlayer+0x220] (forçage en ServerCharacterEntity par 0x14039aca0, lu en 0x140ed5a07), qui pointe son joueur en [personnage+0x2b8] (0x1407b9a5f, 0x140bd7334). Une connexion est locale (client dans le même processus) quand son adresse de pair [connexion+0x5b8] passe par la socket mémoire : gestionnaire [ServerPeer+0x4518] en mémoire seule (table 0x1439cf8a8), ou composite (0x143becc40) avec l'octet de sorte 0 (sorte & 3 : 0 sous-socket +0x10 mémoire, 1 sous-socket +0x18 DirtySDK, lu en 0x14be85a6c). « poser » écrit player_list.s en 0x142b38000 (zone int3 de .xcode) : players(tableau de 4) rend les personnages des joueurs connectés (repli : la case 0x142b2abf0 si aucun), is_player(entité), nearest_player(entité) ; le code des IA (perception.s, target.s, behaviours.s, shots.s) les appelle, et leurs scripts le posent d'abord. « etat » liste connexions, joueurs et personnages, avec la position serveur de chacun (+0x1b0 et translation de la transformation), pour voir si le serveur suit un joueur distant."""

import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

CODE_ADDRESS, CODE_END = 0x142B38000, 0x142B3896B
PLAYERS, IS_PLAYER, NEAREST_PLAYER = CODE_ADDRESS, CODE_ADDRESS + 8, CODE_ADDRESS + 0x10
CODE = open(os.path.join(HERE, "player_list.bin"), "rb").read()
SERVER_CONTEXT = 0x1446CECA0
SERVER_PEER_TABLE = 0x143B65598
SERVER_CONNECTION_TABLE = 0x143A574E8
SERVER_CHARACTER = 0x143A75900
MEMORY_MANAGER, COMPOSITE_MANAGER = 0x1439CF8A8, 0x143BECC40
CONNECTION_LIMIT, ENTRY_LIMIT = 16, 8


def install(process) -> str:
    if CODE_ADDRESS + len(CODE) > CODE_END:
        sys.exit("player_list.bin trop long pour son emplacement")
    present = process.read(CODE_ADDRESS, len(CODE))
    if present == CODE:
        return "liste des joueurs déjà posée"
    if any(byte != 0xCC for byte in present):
        sys.exit(f"autre version de player_list.s en {CODE_ADDRESS:#x} : relancer le jeu")
    process.memory.seek(CODE_ADDRESS)
    process.memory.write(CODE)
    return "liste des joueurs posée"


def pointer(value: int) -> bool:
    return value & 7 == 0 and 0x10000 <= value < 0x7FF000000000


def connection_is_local(process, manager_table: int, connection: int) -> bool | None:
    if manager_table == MEMORY_MANAGER:
        return True
    if manager_table == COMPOSITE_MANAGER:
        kind = process.read(connection + 0x5B8, 1)[0] & 3
        return {0: True, 1: False}.get(kind)
    return None


def server_players(process) -> list[tuple[int, bool | None, int, int]] | None:
    """(connexion, locale, ServerPlayer, personnage ou 0) de chaque fiche ; None si le serveur n'est pas lisible."""
    try:
        context = process.qword(SERVER_CONTEXT)
        if not pointer(context):
            return None
        peer = process.qword(context + 0xB8)
        if not pointer(peer) or process.qword(peer) != SERVER_PEER_TABLE:
            return None
        manager = process.qword(peer + 0x4518)
        manager_table = process.qword(manager) if pointer(manager) else 0
        begin, end = process.qword(peer + 0x45A8), process.qword(peer + 0x45B0)
        found = []
        for slot in range(begin, min(end, begin + 8 * CONNECTION_LIMIT), 8):
            connection = process.qword(slot)
            if not pointer(connection) or process.qword(connection) != SERVER_CONNECTION_TABLE:
                continue
            local = connection_is_local(process, manager_table, connection)
            first, last = process.qword(connection + 0xA90), process.qword(connection + 0xA98)
            for entry_slot in range(first, min(last, first + 8 * ENTRY_LIMIT), 8):
                entry = process.qword(entry_slot)
                player = process.qword(entry + 0xF8) if pointer(entry) else 0
                if not pointer(player):
                    continue
                character = process.qword(player + 0x220)
                valid = pointer(character) and process.qword(character) == SERVER_CHARACTER and process.qword(character + 0x2B8) == player
                found.append((connection, local, player, character if valid else 0))
        return found
    except OSError:
        return None


def local_characters(process) -> list[int] | None:
    """Personnages des joueurs dont le client est dans ce processus ; None si une connexion reste indéterminée ou le serveur illisible."""
    found = server_players(process)
    if found is None or any(local is None for _, local, _, _ in found):
        return None
    return [character for _, local, _, character in found if local and character]


def main() -> None:
    sys.path.insert(0, os.path.join(HERE, "..", "health"))
    from health_mirror import Process
    pid, action = int(sys.argv[1]), sys.argv[2]
    process = Process(pid)
    if action == "poser":
        print(install(process))
    elif action == "etat":
        found = server_players(process)
        if found is None:
            print("serveur interne illisible (pas de mission en cours ?)")
            return
        for connection, local, player, character in found:
            position = ""
            if character:
                block = process.qword(character + 0x58)
                row = block + (process.read(block + 9, 1)[0] + 2 * process.read(block + 0xA, 1)[0]) * 32 + 0x40
                position = " ; position +0x1b0 {:.1f} {:.1f} {:.1f}, transformation {:.1f} {:.1f} {:.1f}".format(
                    *struct.unpack("<3f", process.read(character + 0x1B0, 12)), *struct.unpack("<3f", process.read(row, 12)))
            print(f"connexion {connection:#x} {'locale' if local else 'distante' if local is False else 'indéterminée'} : joueur {player:#x}, personnage {character:#x}{position}")
        print(f"personnages locaux : {', '.join(f'{c:#x}' for c in local_characters(process) or []) or 'aucun'}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
