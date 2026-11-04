"""Usage : python3 -I ultimate.py PID {etat|remplir|cibles|retirer_cibles} : « cibles » fait toujours répondre vrai au test « a des cibles » de DylanFireRateBehavior_TargetedBurst (vf100 et vf108, entrées 0x143a9d650/0x143a9d658, d'origine 0x140d10fd0, vers 0x14036d060), dont la file de cibles verrouillées reste vide faute de cible visée côté serveur (ServerAimingComponent sans mise à jour) : l'arme d'ultime tire alors sa rafale sans cible ; « retirer_cibles » remet l'origine. Lit ou remplit aussi la jauge d'ultime du joueur (personnage serveur dont [entité+0x2b8] est non nul, copie cliente reconnue à sa jauge égale, à 0,5 près, à celle du personnage serveur). Côté serveur, ServerGearComponent (table 0x143a876c0) : interface en +0x30, maximum [+0x30+0x198], valeur [+0x30+0x718] (lecteur 0x148ab9320) ; côté client, ClientGearComponent (table 0x143a8c8d8) : interface en +0x38, maximum [+0x38+0x198], valeur [[+0x38+0xf48]+0x454] (lecteur 0x148b14a40). La jauge pleine est testée par 0x14893f4d0 (valeur = maximum)."""

import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "health"))
from health_mirror import Process

SERVER_GEAR = 0x143A876C0
CLIENT_GEAR = 0x143A8C8D8
SERVER_INTERFACE, CLIENT_INTERFACE = 0x30, 0x38


HAS_TARGETS_SLOTS = (0x143A9D650, 0x143A9D658)
HAS_TARGETS_ORIGINAL, ALWAYS_TRUE = 0x140D10FD0, 0x14036D060


def main() -> None:
    pid, action = int(sys.argv[1]), sys.argv[2]
    process = Process(pid)
    if action in ("cibles", "retirer_cibles"):
        wanted = ALWAYS_TRUE if action == "cibles" else HAS_TARGETS_ORIGINAL
        for slot in HAS_TARGETS_SLOTS:
            if process.qword(slot) not in (ALWAYS_TRUE, HAS_TARGETS_ORIGINAL):
                sys.exit(f"entrée {slot:#x} inattendue")
            process.memory.seek(slot)
            process.memory.write(struct.pack("<Q", wanted))
        print(f"test « a des cibles » de TargetedBurst -> {wanted:#x}")
        return
    found, _ = process.instances([SERVER_GEAR, CLIENT_GEAR], process.regions())
    meters = []
    for component in found[SERVER_GEAR]:
        try:
            if not process.qword(process.qword(process.qword(component + 8)) + 0x2B8):
                continue
        except OSError:
            continue
        interface = component + SERVER_INTERFACE
        meters.append(("serveur", component, interface + 0x198, interface + 0x718))
    for component in found[CLIENT_GEAR]:
        interface = component + CLIENT_INTERFACE
        try:
            state = process.qword(interface + 0xF48)
        except OSError:
            continue
        if state:
            meters.append(("client", component, interface + 0x198, state + 0x454))
    player_values = [process.float(value) for side, _, _, value in meters if side == "serveur"]
    meters = [meter for meter in meters if meter[0] == "serveur" or any(abs(process.float(meter[3]) - value) < 0.5 for value in player_values)]
    for side, component, maximum_address, value_address in meters:
        try:
            maximum, value = process.float(maximum_address), process.float(value_address)
        except OSError:
            continue
        if not 0.0 < maximum <= 10000.0:
            continue
        if action == "remplir":
            process.write_float(value_address, maximum)
        print(f"{side} {component:#x} jauge {value:.1f}/{maximum:.1f}" + (" -> pleine" if action == "remplir" else ""))
    if action not in ("etat", "remplir"):
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
