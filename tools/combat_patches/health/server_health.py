"""Usage : python3 -I server_health.py PID {poser|retirer|etat} : remplace le rappel serveur d'impacts (server_damage.py) par le code impacts.s (0x142b2c800). Pour chaque impact reçu (+0x38 poignée de la cible, +0x40 poignée du tireur, +0xa0 vitesse du projectile), ancien montant : +0xa0 (sans multiplicateur forfaitaire depuis le 2026-11-04), puis multiplié par le bonus de dégâts du joueur (flottant 0x1537377e8, réglé par damage.py, ignoré s'il est nul) sauf pour un tir d'IA de shots.s (rcx = 1). Tir d'arme du joueur (rcx ni 1 ni 2, marque des sections de server_sections.py, et +0xa0 d'au moins 100) : le montant passé à 0x140c86ef0 est le dégât Damage_Impact_Physical de l'arme active, sans bonus, lu ainsi : tireur [[+0x40]]-8, ServerDylanCharacter (0x143a75900) joueur ([+0x2b8] non nul) ; son ServerGearComponent (table 0x143a876c0) dans [+0x58] (compte en +8, entrées de 0x20 depuis +0x10, composant en +0x10) ; emplacement actif [+0x774] (1 ou 5, basculé par 0x140c802df) cherché dans le tableau [+0x38, +0x40[ d'entrées de 0x88 octets (clé en +0, entité en +0x20, comme 0x140c2c2a0) ; ServerActionGearEntity (0x143a5bf40) ; son EntityBus [+0x28] (0x143bb1148), dont les bus des pièces (premier +0x30, suivant +0x28) portent l'instance de la classe vars de la pièce en +0x70 ; dans la chaîne des TypeInfo de l'instance ([+0x10], TypeInfoData [TypeInfo], champs [+0x38] de 16 octets {hachage, drapeaux, décalage +6, TypeInfo +8}, nombre +0x2a, parent +0x30), le champ de hachage 0x4d6f4827 de type flottant (0x9c76c920) ; valeur à instance + décalage, donc le réglage de /api/gameconfig/tuning, sinon la valeur d'origine. Bornes : 64 emplacements, 32 pièces, 8 classes, 256 champs ; valeur hors de ]0, 100000[ refusée. Compteurs en 0x1537377d0 : tirs d'arme (u32), replis (u32 : chemin en échec, ancien montant gardé), dernier dégât d'arme (flottant), remis à 0 par « poser ». Pas de mise à l'échelle par niveau : la valeur de l'instance est passée telle quelle (objets servis au niveau 1). Le montant passe par 0x140c86ef0, qui le range en [info+0xd0] et appelle 0x140c15020 : pour un personnage, bouclier, vie, mort et diffusion OnDamage passent par l'ApplyDamage natif rétabli par damage.py (à poser avec published_health.py). Les objets destructibles n'ont pas cette famille de composants et gardent l'ancien montant : pour un ServerCombatPlaceableHealthComponent (table 0x143a740a0, ignoré si Immortal +0xe2), il met la vie à 1/1 si elle n'a jamais été posée, retire ancien montant / DylanMaxHealth (données +0xa0, 100 par défaut) et note le composant dans l'anneau 0x153737f80 (lu par health_follow.py). À 0, il passe l'état [+0x100] à 2, coupe la physique serveur (0x140959e00(entité+0x170, 0)), lance OnDestroyed (0x141b465b0, 0xa96f26e7) et publie IsDestroyed. « etat » lit les compteurs et liste les composants de santé serveur et leur vie."""

import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from health_mirror import Process

HERE = os.path.dirname(os.path.abspath(__file__))
CODE_ADDRESS = 0x142B2C800
OLDER_CODES = (0x142B28000, 0x142B28200, 0x142B28700, 0x142B28A00, 0x142B29200, 0x142B29C00, 0x142B2A400, 0x142B2B400, 0x142B2C000)
PREVIOUS_CODE = 0x142B27F00
CALLBACK_OBJECT = 0x144759E68
CALLBACK_FUNCTION = 0x144759E70
SIMPLE_HEALTH_TABLE = 0x143A88538
CODE = open(os.path.join(HERE, "impacts.bin"), "rb").read()
WEAPON_COUNTERS = 0x1537377D0


def main() -> None:
    pid, action = int(sys.argv[1]), sys.argv[2]
    process = Process(pid)
    obj, fn = process.qword(CALLBACK_OBJECT), process.qword(CALLBACK_FUNCTION)
    if action == "etat":
        print(f"rappel objet={obj:#x} fonction={fn:#x} ({'health' if fn == CODE_ADDRESS else 'dégâts seuls' if fn == PREVIOUS_CODE else 'aucun' if not fn else 'inattendu'})")
        shots, fallbacks, last = struct.unpack("<IIf", process.read(WEAPON_COUNTERS, 12))
        print(f"tirs d'arme {shots}, replis {fallbacks}, dernier dégât d'arme {last:g}")
        found, _ = process.instances([SIMPLE_HEALTH_TABLE], process.regions())
        for component in found[SIMPLE_HEALTH_TABLE]:
            current, maximum = struct.unpack("<ff", process.read(component + 0x20, 8))
            print(f"  {component:#x} vie={current:g}/{maximum:g}")
    elif action == "poser":
        if fn not in (0, PREVIOUS_CODE, CODE_ADDRESS) + OLDER_CODES:
            sys.exit(f"rappel inattendu {fn:#x}")
        current = process.read(CODE_ADDRESS, len(CODE))
        if current != CODE:
            if fn == CODE_ADDRESS:
                sys.exit("ancienne version du code en service : retirer d'abord")
            if set(current) != {0xCC} and not current.startswith(CODE[:16]):
                sys.exit("emplacement du code non vide")
            process.write(CODE_ADDRESS, CODE)
        process.write(WEAPON_COUNTERS, bytes(12))
        process.write(CALLBACK_FUNCTION, struct.pack("<Q", CODE_ADDRESS))
        if not obj:
            process.write(CALLBACK_OBJECT, struct.pack("<Q", CODE_ADDRESS))
        print(f"posé : rappel -> {CODE_ADDRESS:#x}")
    elif action == "retirer":
        if fn == CODE_ADDRESS:
            back = PREVIOUS_CODE if process.read(PREVIOUS_CODE, 1) != b"\xcc" else 0
            process.write(CALLBACK_FUNCTION, struct.pack("<Q", back))
            if not back:
                process.write(CALLBACK_OBJECT, bytes(8))
            print(f"retiré : rappel -> {back:#x}")
        else:
            print("rien à retirer")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
