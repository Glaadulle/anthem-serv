"""Usage : python3 -I perception.py PID {poser|retirer|etat} : perception par IA et choix de la cible hostile perçue la plus proche (code perception.s en 0x142b30000), à poser après target.py dont les entrées restent le repli des IA qui ne sont pas des personnages serveur. Entrées déviées : EntityProvider_AITarget (0x143acf790), BTConditional_HasEnemies (0x143ad02b8), BTConditional_LOSToTarget/HeardSound (0x143ad0058), BoolProvider_WantsToAttack (0x143acf7d8), BTConditional_RangeToTarget (0x143ad0240) et BTConditional_TargetIsPlayer (0x143ad0080). Paramètres : PerceptionComponentData (type 0x1451ca740) n'est pas instancié côté serveur ; il est lu dans le tableau des composants des données du personnage ([[entité+0x30]+0x70], DylanCharacterData) : entrée PerceptionData (+0xc0, 0x28 octets, StateType +0x24) de l'état d'IA [IA+0xc0], sinon DefaultPerceptionParams (+0x88) ; SightRadius +0 (0 : aveugle), TimeToPerceive +0x18, TimeToUnperceive +0x1c, BroadcastToAlliesRadius +0xd0, FirstAlertBroadcastRadius +0xd8 ; défauts sans données : 60 m, 0,5 s, 10 s, 30 m, pas de première alerte. Hostilité : groupe d'un personnage = ServerHostilityComponent (table 0x143bca3d0) : première surcharge [comp+0x58] si la pile [comp+0x58..0x60] n'est pas vide, sinon [comp+0x78] ; relation = table de hachage du ServerHostilityManager [0x14470de38] (+0x40 seaux, +0x48 nombre ; clé groupe source, suivant +0x38, sous-table +0x10/+0x18 ; clé groupe cible, suivant +0x10 ; [nœud+8]+0x28 = HostilityType 0 ami, 1 neutre, 2 hostile ; absent : 1). Candidats : les personnages des joueurs connectés (jusqu'à 4, player_list.s en 0x142b38000, posé d'abord ; repli : la case 0x142b2abf0) et les IA des fiches évaluées depuis moins d'1 s, utilisables (position sous garde, vie > 0) et hostiles à l'IA. Au plus toutes les 0,25 s par IA : les trois candidats hostiles les plus proches à moins de SightRadius sont testés par lancer de rayon dans l'ordre des distances (rayon serveur [[0x1446e54a8]+0x60], 0x14159eec0, des yeux de l'IA +1,7 m à la cible +1,5 m, dégagé si l'impact est à moins de 2 m de la cible) ; le premier visible depuis TimeToPerceive devient la cible ; la cible courante encore à portée et visible est repérée de nouveau, sans second rayon si elle était parmi les candidats déjà testés. Le code est assemblé pour son adresse (appels et lectures relatifs à rip vers le jeu) : as puis objcopy -O binary -j .text. Sans cible perçue : baisse de vie + bouclier (ServerRegeneratingShieldComponent 0x143a76ae0, [[comp+0x50]]) constatée depuis moins de 10 s → candidat hostile le plus proche ([IA+0xbc] n'est pas utilisé : il avance sur des messages de dégâts sans perte) ; sinon une IA amie évaluée depuis moins d'1 s qui perçoit une cible hostile à l'IA la lui transmet avec sa propre heure de repérage, si elle est à moins de BroadcastToAlliesRadius, ou de FirstAlertBroadcastRadius quand elle a acquis sa cible depuis moins d'1 s. Oubli après TimeToUnperceive. Effet : AITarget = cible, HasEnemies et WantsToAttack = cible perçue, LOSToTarget = visibilité de la cible au dernier choix, RangeToTarget = distance à la cible (2D si Is2DRange, écart vertical seul si HeightOnlyCheck +0x31) comparée à Range, TargetIsPlayer = la cible est un joueur (personnage serveur dont [+0x2b8], son ServerPlayer, est non nul, ou la case 0x142b2abf0). Fiches : 128 × 0x50 octets {entité, cible, visible depuis, repérée à, évaluée à, oubli, prochain choix, visible, état, candidat visible, SightRadius, distance au repérage, vie + bouclier, blessée à, alertée à, rayons, rayons dégagés, écart du dernier impact}, allouées au premier besoin par l'allocateur du jeu (0x1403bb060, arène [0x1446b4110]) et pointées par 0x153737618, reprises après 5 s sans évaluation. Sans fiche : la cible est le joueur hostile le plus proche. La fonction cible_de(entité) (0x142b30030) est publiée en 0x153737608 pour shots.s et behaviours.s, et remise à 0 au retrait. La pose est refusée sans lanceur de rayon serveur ; le code n'est réécrit que si aucune entrée ne pointe dessus. « etat » n'affiche que les fiches évaluées depuis moins de 5 s."""

import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "health"))
sys.path.insert(0, HERE)
from health_mirror import Process
import player_list

CODE_ADDRESS = 0x142B30000
CODE_END = 0x142B316C0
PREVIOUS = CODE_ADDRESS + 0x40
TARGET_OF = CODE_ADDRESS + 0x30
TARGET_OF_SLOT = 0x153737608
RECORDS_POINTER, RECORD_COUNT, RECORD_SIZE = 0x153737618, 128, 0x50
BLOCKED_RAY = 0x153737620
CLOCK_OWNER = 0x1446CECA0
STALE = 5.0
SLOTS = (("AITarget", 0x143ACF790), ("HasEnemies", 0x143AD02B8), ("LOSToTarget", 0x143AD0058),
         ("WantsToAttack", 0x143ACF7D8), ("RangeToTarget", 0x143AD0240), ("TargetIsPlayer", 0x143AD0080))
SERVER_RAY_CASTER_OWNER, RAY_CASTER_TABLE = 0x1446E54A8, 0x143B44520
CODE = open(os.path.join(HERE, "perception.bin"), "rb").read()


def entry(index: int) -> int:
    return CODE_ADDRESS + 8 * index


def main() -> None:
    pid, action = int(sys.argv[1]), sys.argv[2]
    process = Process(pid)
    write = process.write

    if action == "poser":
        owner = process.qword(SERVER_RAY_CASTER_OWNER)
        caster = process.qword(owner + 0x60) if owner else 0
        if not caster or process.qword(caster) != RAY_CASTER_TABLE:
            sys.exit(f"lanceur de rayon serveur absent ([{SERVER_RAY_CASTER_OWNER:#x}] = {owner:#x}, lanceur {caster:#x}) : perception non posée")
        if CODE_ADDRESS + len(CODE) > CODE_END:
            sys.exit("code trop long pour l'emplacement")
        player_list.install(process)
        present = process.read(CODE_ADDRESS, len(CODE))
        if present[:PREVIOUS - CODE_ADDRESS] + present[PREVIOUS - CODE_ADDRESS + 8 * len(SLOTS):] != CODE[:PREVIOUS - CODE_ADDRESS] + CODE[PREVIOUS - CODE_ADDRESS + 8 * len(SLOTS):]:
            hooked = [name for name, slot in SLOTS if CODE_ADDRESS <= process.qword(slot) < CODE_END]
            if hooked:
                sys.exit(f"autre version du code en service ({', '.join(hooked)}) : la retirer d'abord")
            write(CODE_ADDRESS, CODE)
        report = []
        for index, (name, slot) in enumerate(SLOTS):
            current = process.qword(slot)
            if current == entry(index):
                report.append(f"{name} déjà posé")
                continue
            write(PREVIOUS + index * 8, struct.pack("<Q", current))
            write(slot, struct.pack("<Q", entry(index)))
            report.append(f"{name} (repli {current:#x})")
        write(TARGET_OF_SLOT, struct.pack("<Q", TARGET_OF))
        print("posé : " + ", ".join(report))
    elif action == "retirer":
        write(TARGET_OF_SLOT, bytes(8))
        report = []
        for index, (name, slot) in enumerate(SLOTS):
            if process.qword(slot) == entry(index):
                previous = process.qword(PREVIOUS + index * 8)
                write(slot, struct.pack("<Q", previous))
                report.append(f"{name} -> {previous:#x}")
        print("retiré : " + (", ".join(report) or "rien à retirer"))
    elif action == "etat":
        for index, (name, slot) in enumerate(SLOTS):
            current = process.qword(slot)
            print(f"{name} : {'perception' if current == entry(index) else hex(current)} (repli {process.qword(PREVIOUS + index * 8):#x})")
        print(f"cible_de publiée : {process.qword(TARGET_OF_SLOT):#x}")
        records = process.qword(RECORDS_POINTER)

        def name_of(entity: int) -> str:
            try:
                return process.read(process.qword(process.qword(entity + 0x320) + 0x20), 90).split(b"\0")[0].decode(errors="replace").rsplit("+", 1)[-1][:40]
            except OSError:
                return "?"

        clock = process.qword(process.qword(CLOCK_OWNER) + 0x18)
        now = struct.unpack("<d", process.read(clock + 0x10, 8))[0]
        stale = 0
        for record in range(records, records + RECORD_COUNT * RECORD_SIZE if records else records, RECORD_SIZE):
            (entity, target, since, seen, evaluated, forget, _, visible, state, candidate, sight, spot,
             vitality, damaged, alerted, rays, clear, gap) = struct.unpack("<QQfffffBB2xQfffffIIf", process.read(record, RECORD_SIZE))
            if not entity:
                continue
            if now - evaluated > STALE:
                stale += 1
                continue
            perceived = seen > 0 and evaluated - seen <= forget
            cible = f"{target:#x} {name_of(target)}" if target else "aucune"
            print(f"{entity:#x} {name_of(entity)} (état {state}, vue {sight:.0f} m, oubli {forget:.0f} s) : {'perçoit' if perceived else 'ne perçoit pas'} {cible}, "
                  f"{'visible' if visible else 'cachée'}, {f'repérée il y a {now - seen:.1f} s à {spot:.1f} m' if seen else 'non repérée'}, "
                  f"rayons {clear}/{rays} dégagés{f', dernier impact à {gap:.1f} m de la cible' if rays > clear else ''}, "
                  f"{f'blessée il y a {now - damaged:.1f} s' if damaged else 'jamais blessée'}, vie+bouclier {vitality:.2f}")
        print(f"temps serveur {now:.1f} ; fiches périmées (plus de {STALE:.0f} s sans évaluation) : {stale}")
        ai, target = struct.unpack("<QQ", process.read(BLOCKED_RAY, 16))
        start, end, impact = (struct.unpack("<3f4x", process.read(BLOCKED_RAY + offset, 16)) for offset in (0x10, 0x20, 0x30))
        body, count = struct.unpack("<QI", process.read(BLOCKED_RAY + 0x40, 12))
        if count:
            print(f"rayons bloqués : {count} ; dernier : {ai:#x} {name_of(ai)} vers {target:#x} {name_of(target)}, départ {start[0]:.1f} {start[1]:.1f} {start[2]:.1f}, "
                  f"impact à {math.dist(start, impact):.1f} m du départ sur {math.dist(start, end):.1f} m ({impact[0]:.1f} {impact[1]:.1f} {impact[2]:.1f}), corps touché {body:#x}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
