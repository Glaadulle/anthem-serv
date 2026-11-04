"""Usage : python3 -I published_health.py PID {poser|publier|retirer|etat|relevement oui|non} : rend aux composants de santé serveur (ServerDylanHealthComponent 0x143a88050 du joueur, ServerDylanSimpleHealthComponent 0x143a88538 des IA) leur vie en points, comme les lit le code natif (interface santé 0x143a87fb0 : vf20 = [+0x20] vie, vf28 = [+0x24] maximum). Le maximum réel est la propriété DylanMaxHealth (djb2 0x9f424473) que publie la DylanHealthSettingsEntity de chaque personnage (table 0x143a795e8, seconde table en +0x30 : 0x143a796b8, dont le vf30 (0x140c13f70 → 0x14892ce40) évalue les formules : 26 fiches de 0x18 octets en entité+0xd0, poignée en +0x10 : valeur [[poignée]], identifiant [poignée+0x18], composant visé [poignée+0x10]) ; le composant serveur, dont l'init et la mise à jour sont retirées, ne la lit jamais et reste à 1/1. Code published_health.s (0x142b2e400) : SetHealth (vf100 de 0x143a88538, d'origine `ret 0` 0x140367dc0 ; aussi point d'entrée set_health de damage.s) borne les points dans [0, [+0x24]], les range en [+0x20], en déduit la fraction [+0x128] (interface santé +0x80, mise à 1 par 0x140c14e70 et lue côté serveur par FloatProvider_CurrentHealthPct 0x1486e5e20 et CSMConditionCheckHealth 0x1486d0cc0 ; aussi tenue par apply_max), réplique vie et maximum par le marquage réseau natif (replicate 0x142b2e5f0 : 0x141e5e2c0(comp+0x1e8, masque) si [comp+0x1e8] = 0x143a881f8 ; bits de l'écrivain 0x140c7d440 : 1 vie, 2 maximum, 8 état [+0x158]) et publie CurrentHealth par la poignée [comp+0x38] (composant simple seul) ; settings_update (0x142b2e620) remplace ce vf30 (emplacement 0x143a796e8) : après l'évaluation d'origine, chaque DylanMaxHealth publiée vers un composant de santé serveur en devient le maximum, la vie gardant son ratio (apply_max). player_update (0x142b2e780) remplace la mise à jour par image du composant de santé du joueur (vf150 de 0x143a88050, `ret 0` d'origine, 60 appels comptés en 2 s le 2026-11-01 ; le vf68 de l'interface, essayé d'abord, n'est jamais appelé) : si le relèvement automatique est demandé (octet 0x1537377e5 à 1, « relevement oui » ; coupé par défaut comme dans le jeu d'origine), pour le joueur à terre (état 1, agonie posée par damage.s), il compte 240 images (8 s) puis le relève (compteur propre à chaque joueur : table de 4 fiches {composant, images, dernier compteur d'équipe relevée vu, ordre} en 0x153737a00, horloge d'ordre 0x153737a60, la fiche la plus ancienne reprise pour un nouveau composant) (état 0 répliqué, vie au maximum, DylanHealthCompReviveMessage 0x2f592866, table 0x143a8b658, diffusé aux composants de l'entité et au bus serveur comme l'agonie : le client le diffuse aussi chez lui au passage 1 → 0 de 0x140cba3a0, et ses récepteurs serveur sont ServerDeathManagerEntity 0x14877bd60, ServerGearComponent 0x140c7fc00 et d'autres), en attendant la réanimation par un allié ; il relève aussi tout de suite le joueur sur demande (octet 0x1537377e4 à 1, posé par « shots.py soigner » ; compteur 0x1537377e0). Réapparition (maintien de F à terre) : le schéma EXO_DeadStateRelease fait accepter par ServerRequestPlayerRespawnTransitionEntity (0x140ed5760) une transition de type 5 (appel 0x140edeae0 en 0x140ed59da, joueur serveur dans r15), puis lance OnRespawn, que le schéma traite comme une réanimation ; la remise en état de la santé n'existe plus côté serveur (essai du jeu 218011 : joueur déplacé, resté à 0 état 1). « poser » dévie cet appel vers respawn_call (0x142b2e900) : appel d'origine, puis personnage 0x14039aca0([joueur+0x220]) et, s'il est à terre, relèvement de son ServerDylanHealthComponent (revive_player : état 0 répliqué, vie au maximum, DylanHealthCompReviveMessage, qui retire aussi le joueur de la liste [+0x78] de ServerDeathManagerEntity). « retirer » remet l'appel d'origine. Équipe entière à terre (un joueur seul compte, quand l'octet +0x75 de la mission lu par 0x140b2b0f0 est vrai) : le gestionnaire n'ajoute aucune entrée, refuse donc F, et au bout de PartyReviveDelay envoie DeathManagerRevivePartyMessage, que seul EcoQuestResetToCheckPointEntity (retour au point de contrôle) traite ; sans cette entité dans le niveau (essai du jeu 43342), le joueur reste à terre. L'envoi (0x140b2ac80, appel de 0x1403e7c60) est dévié vers party_revive_call (0x142b2e9a0), qui envoie le message puis incrémente le compteur 0x1537377f4 ; compteurs d'appels de respawn_call et party_revive_call en 0x1537377f0 et 0x1537377f4, affichés par « etat » ; player_update relève alors sur place chaque joueur à terre dont la fiche n'a pas encore vu la nouvelle valeur du compteur (tous les joueurs à terre, pas seulement le premier mis à jour). « poser » applique aussi une fois ce maximum aux composants existants, dont les réglages ont été évalués avant la pose (écriture directe, réplication au prochain changement de vie). Le prefab Ally_Creature_ReviveInteraction_Exo met un allié à terre par SetHealth(1) (CallFunction 8FB00E7D, Revive_ForceDownedState) quand CurrentHealth == 1 sans bouclier, et le relève par SetHealth(GetMaxHealth()) (6FB02EC1) ; « poser » (puis « publier » à la demande) resynchronise les composants dont la poignée CurrentHealth vise l'entrée 0xb208be4f du prefab (4 par passe) : 1 point si Revive_ForceDownedState est vrai, sinon leur vie ; exécuté sur le fil serveur par un détour temporaire de l'évaluateur BoolProvider_VariableTable (0x143a1b6c0+0x10, filtré sur la donnée Revive_ForceDownedState, registres d'arguments préservés), retiré ensuite. Les anciennes versions qui rendaient vie et maximum en points par vf20/vf28 sont défaites à la pose."""

import os
import struct
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from health_mirror import Process

CODE_ADDRESS = 0x142B2E400
CODE_SIGNATURE = bytes.fromhex("534883ec304889cb")
EVALUATOR_ADDRESS = CODE_ADDRESS + 0x100
SETTINGS_UPDATE_ADDRESS = CODE_ADDRESS + 0x220
PLAYER_UPDATE_ADDRESS = CODE_ADDRESS + 0x380
RESPAWN_CALL_ADDRESS = CODE_ADDRESS + 0x500
PARTY_REVIVE_CALL_ADDRESS = CODE_ADDRESS + 0x5A0
RESPAWN_CALL_SITE = 0x140ED59DA
REQUEST_TRANSITION = 0x140EDEAE0
PARTY_REVIVE_CALL_SITE = 0x140B2AC80
BUS_SEND = 0x1403E7C60
AUTO_REVIVE = 0x1537377E5
DOWNED_FRAMES_COUNTERS = 0x1537377F0
PLAYER_TABLE, PLAYER_TABLE_SIZE = 0x153737A00, 0x68
CODE = open(os.path.join(HERE, "published_health.bin"), "rb").read()
SERVER_HEALTH = 0x143A88538
PLAYER_HEALTH = 0x143A88050
HEALTH_INTERFACE = 0x143A87FB0
HEALTH_SETTINGS = 0x143A795E8
SETTINGS_EVALUATE_SLOT = 0x143A796E8
SLOTS = ((SERVER_HEALTH + 0x100, 0x140367DC0, CODE_ADDRESS),
         (SETTINGS_EVALUATE_SLOT, 0x140C13F70, SETTINGS_UPDATE_ADDRESS),
         (PLAYER_HEALTH + 0x150, 0x140367DC0, PLAYER_UPDATE_ADDRESS))
OLDER_SLOTS = ((HEALTH_INTERFACE + 0x20, 0x140C7C0C0), (HEALTH_INTERFACE + 0x28, 0x140C7C090), (HEALTH_INTERFACE + 0x68, 0x140367DC0))
DYLAN_MAX_HEALTH = 0x9F424473
SETTINGS_ENTRIES, SETTINGS_ENTRY_SIZE, SETTINGS_FIRST = 26, 0x18, 0xD0
PROVIDER_TABLE = 0x143A1B6C0
PROVIDER_TYPE = 0x145297C40
EVALUATOR_SLOT = PROVIDER_TABLE + 0x10
EVALUATOR_ORIGINAL = 0x1407D7CB0
STATE = 0x153737780
FORCE_DOWNED_HASH = 0xD8BFFA3F
REVIVE_HEALTH_INPUT = 0xB208BE4F
BATCH = 4


def pack(value: int) -> bytes:
    return struct.pack("<Q", value)


def float_at(process: Process, address: int) -> float:
    return struct.unpack("<f", process.read(address, 4))[0]


def call_to(site: int, target: int) -> bytes:
    return b"\xe8" + struct.pack("<i", target - site - 5)


CALL_SITES = ((RESPAWN_CALL_SITE, call_to(RESPAWN_CALL_SITE, REQUEST_TRANSITION), call_to(RESPAWN_CALL_SITE, RESPAWN_CALL_ADDRESS)),
              (PARTY_REVIVE_CALL_SITE, call_to(PARTY_REVIVE_CALL_SITE, BUS_SEND), call_to(PARTY_REVIVE_CALL_SITE, PARTY_REVIVE_CALL_ADDRESS)))


def install_code(process: Process) -> None:
    code = process.read(CODE_ADDRESS, len(CODE))
    if code == CODE:
        return
    if set(code) != {0xCC} and not code.startswith(CODE_SIGNATURE):
        sys.exit("emplacement du code non vide")
    for site, original, _ in CALL_SITES:
        process.write(site, original)
    for slot, original in OLDER_SLOTS:
        process.write(slot, pack(original))
    for slot, original, _ in SLOTS:
        process.write(slot, pack(original))
    process.write(PLAYER_TABLE, bytes(PLAYER_TABLE_SIZE))
    process.write(CODE_ADDRESS, CODE)


def published_maxima(process: Process, settings: list[int]) -> dict[int, float]:
    maxima = {}
    for entity in settings:
        try:
            if process.qword(entity) != HEALTH_SETTINGS:
                continue
            for index in range(SETTINGS_ENTRIES):
                handle = process.qword(entity + SETTINGS_FIRST + index * SETTINGS_ENTRY_SIZE + 0x10)
                if not handle or struct.unpack("<I", process.read(handle + 0x18, 4))[0] != DYLAN_MAX_HEALTH:
                    continue
                component = process.qword(handle + 0x10)
                if process.qword(component) in (SERVER_HEALTH, PLAYER_HEALTH):
                    maxima[component] = float_at(process, process.qword(handle))
        except OSError:
            continue
    return maxima


def apply_maxima(process: Process, maxima: dict[int, float]) -> None:
    for component, maximum in sorted(maxima.items()):
        current, previous = struct.unpack("<ff", process.read(component + 0x20, 8))
        if maximum <= 0 or maximum == previous:
            continue
        ratio = min(current / previous, 1.0) if previous > 0 else 1.0
        process.write(component + 0x20, struct.pack("<ff", ratio * maximum, maximum))
        print(f"{component:#x} maximum {previous:g} -> {maximum:g}, vie {ratio * maximum:g}")


def revive_components(process: Process, healths: list[int]) -> list[int]:
    result = []
    for component in sorted(set(healths)):
        try:
            handle = process.qword(component + 0x38)
            if handle and struct.unpack("<I", process.read(handle + 0x18, 4))[0] == REVIVE_HEALTH_INPUT:
                result.append(component)
        except OSError:
            continue
    return result


def force_downed_provider(process: Process, providers: list[int]) -> int:
    for provider in providers:
        try:
            if process.qword(provider + 0x10) == PROVIDER_TYPE and struct.unpack("<I", process.read(provider + 0x38, 4))[0] == FORCE_DOWNED_HASH:
                return provider
        except OSError:
            continue
    return 0


def force_downed(process: Process, component: int) -> bool:
    entity = process.qword(process.qword(component + 8))
    variables = process.qword(process.qword(entity + 0x28) + 0x70)
    table = process.qword(variables + 0x10)
    fields, count = process.qword(table + 0x58), struct.unpack("<I", process.read(table + 0x60, 4))[0]
    for index in range(count):
        info = process.qword(process.qword(fields + 8 * index) + 8)
        if struct.unpack("<I", process.read(info, 4))[0] == FORCE_DOWNED_HASH:
            offset = struct.unpack("<H", process.read(info + 6, 2))[0]
            return process.read(variables + offset, 1) != b"\x00"
    return False


def published(process: Process, component: int) -> float:
    return float_at(process, process.qword(process.qword(component + 0x38)))


def publish(process: Process, found: dict[int, list[int]]) -> None:
    components = revive_components(process, found[SERVER_HEALTH])
    provider = force_downed_provider(process, found[PROVIDER_TABLE])
    if not components or not provider:
        print("rien à publier")
        return
    targets = [(component, 1.0 if force_downed(process, component) else float_at(process, component + 0x20)) for component in components]
    print("cibles " + " ".join(f"{component:#x}={value:g}" for component, value in targets))
    try:
        process.write(EVALUATOR_SLOT, pack(EVALUATOR_ADDRESS))
        for start in range(0, len(targets), BATCH):
            batch = targets[start:start + BATCH]
            entries = b"".join(pack(component) + struct.pack("<f4x", value) for component, value in batch) + bytes(16 * (BATCH - len(batch)))
            process.write(STATE + 8, pack(provider) + entries)
            process.write(STATE, b"\x01")
            deadline = time.time() + 15
            while process.read(STATE, 1) == b"\x01" and time.time() < deadline:
                time.sleep(0.1)
            if process.read(STATE, 1) != b"\x02":
                process.write(STATE, b"\x00")
                sys.exit("évaluateur jamais appelé en 15 s")
    finally:
        process.write(EVALUATOR_SLOT, pack(EVALUATOR_ORIGINAL))
    process.write(STATE, bytes(0x50))
    for component in components:
        print(f"{component:#x} vie {float_at(process, component + 0x20):g} publiée {published(process, component):g}")


def search(process: Process) -> dict[int, list[int]]:
    return process.instances([SERVER_HEALTH, PROVIDER_TABLE, HEALTH_SETTINGS], process.regions())[0]


def main() -> None:
    if len(sys.argv) not in (3, 4) or (len(sys.argv) == 4) != (sys.argv[2] == "relevement"):
        sys.exit(__doc__)
    process, action = Process(int(sys.argv[1])), sys.argv[2]
    if action == "etat":
        print(" ; ".join(f"{slot:#x} -> {process.qword(slot):#x}" for slot, _, _ in SLOTS + tuple((slot, original, 0) for slot, original in OLDER_SLOTS))
              + f" ; évaluateur {process.qword(EVALUATOR_SLOT):#x} ; état {process.read(STATE, 1).hex()}"
              + "".join(f" ; appel {site:#x} {'dévié' if process.read(site, 5) == patched else 'd’origine'}" for site, _, patched in CALL_SITES)
              + " ; appels réapparition/équipe relevée {} {}".format(*struct.unpack("<II", process.read(DOWNED_FRAMES_COUNTERS, 8)))
              + f" ; relèvement automatique {'oui' if process.read(AUTO_REVIVE, 1) != b'\x00' else 'non'}")
    elif action == "relevement":
        if sys.argv[3] not in ("oui", "non"):
            sys.exit(__doc__)
        process.write(AUTO_REVIVE, b"\x01" if sys.argv[3] == "oui" else b"\x00")
        print(f"relèvement automatique {sys.argv[3]}")
    elif action == "poser":
        for slot, original, patched in SLOTS:
            if process.qword(slot) not in (original, patched):
                sys.exit(f"slot {slot:#x} inattendu {process.qword(slot):#x}")
        for site, original, patched in CALL_SITES:
            if process.read(site, 5) not in (original, patched):
                sys.exit(f"appel {site:#x} inattendu {process.read(site, 5).hex()}")
        install_code(process)
        for slot, _, patched in SLOTS:
            process.write(slot, pack(patched))
        for site, _, patched in CALL_SITES:
            process.write(site, patched)
        found = search(process)
        apply_maxima(process, published_maxima(process, found[HEALTH_SETTINGS]))
        publish(process, found)
        print(f"posé : SetHealth et maximum publié -> {CODE_ADDRESS:#x}")
    elif action == "publier":
        if process.qword(SLOTS[0][0]) != CODE_ADDRESS:
            sys.exit("poser d'abord")
        publish(process, search(process))
    elif action == "retirer":
        for site, original, _ in CALL_SITES:
            process.write(site, original)
        process.write(EVALUATOR_SLOT, pack(EVALUATOR_ORIGINAL))
        for slot, original, _ in SLOTS:
            process.write(slot, pack(original))
        for slot, original in OLDER_SLOTS:
            process.write(slot, pack(original))
        process.write(STATE, bytes(0x50))
        print("retiré")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
