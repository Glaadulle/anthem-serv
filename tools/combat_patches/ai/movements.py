"""Usage : python3 -I movements.py PID {poser|retirer|etat|mesurer [DUREE]} : rend un déplacement de combat aux IA serveur sans jamais modifier les données du niveau. Les fabriques de comportements de mouvement (table [0x144326b38], [0x144326b40] seaux, nœud {mot type, +8 fonction, +0x10 suivant}, clé = mot +0x38 du type des données) de CircleStrafe, SquadCircle, StayAtRange et MoveToTarget pointent sur le bouchon 0x140463610, et MoveToLOS, MoveFromLOS et Flee n'y figurent pas : BT_SetMovementBehavior (0x146d4a860) ne pose alors aucun comportement. « poser » installe behaviours.s (0x142b2f700) et fait pointer ces sept types sur sa fabrique (entrées existantes réécrites, nœuds manquants ajoutés en 0x153737580 en tête de leur seau). La fabrique cherche ou construit une donnée MovementBehaviorMoveToPoint de substitution (0x90 octets allouée par l'allocateur global du jeu 0x1403bb060 sur l'arène [0x1446b4110], la plus employée par le code ; chaînée depuis 0x153737070 par +0x88, marquée en +0x80 ; jamais libérée ; clé : type d'origine, portée, style de mouvement, orientation) avec nos propres objets uniquement (évaluateurs dynamiques = tableau vide 0x153737578, cible = fournisseur d'entité 0x153737540 qui rend la cible perçue de l'IA du contexte (cible_de publiée par perception.py en 0x153737608) et, à défaut, le joueur connecté le plus proche de l'IA (nearest_player de player_list.s, posé d'abord ; repli : la case 0x142b2abf0), Transform = fournisseur 0x153737500 qui décale le point du joueur sur un cercle de rayon = portée d'origine (Range, DistanceRange, MaxDistanceFromTarget, StopThreshold ; 15 m par défaut, 30 m pour Flee) + 0 à 4,5 m, dans une des 16 directions tirée de l'adresse de l'IA et tournant d'un cran toutes les 8 s ; arrêt à 3 m, but réévalué toutes les 2 s sans mise à jour pendant le déplacement ; pour MoveToTarget, pas de cercle : le but est la cible elle-même, avec le StopThreshold d'origine (borné à 0–100 m, 0 compris), l'UpdatePeriod d'origine (0,33 s à défaut) et le but suivi pendant le déplacement, pour que mêlée et kamikazes atteignent leur cible), puis appelle la fabrique MoveToPoint native 0x140dc4be0. MoveToLOS, MoveFromLOS et Flee passent par la fabrique de lines_of_sight.s (0x142b34000, voir docs/ai-enemy-summary.md) : même substitution, chaînée depuis 0x153737678, avec ses propres fournisseur de position et points de TestLocations recopiés ; « mesurer » lit ses compteurs (0x153737680) sur DUREE secondes (30 par défaut). La comparaison « même comportement » de BT_SetMovementBehavior (0x146d4a8ca, cmp [comportement+0x10], donnée) est déviée vers le code qui reconnaît une substitution de la donnée demandée, pour ne pas recréer le comportement à chaque passage de l'arbre. Le vidage de la table (relais 0x14053c7b0 vers 0x146d56800, appelé à l'initialisation 0x14907e7e8 et à l'arrêt 0x14907ea66 du module serveur, et par 0x142d410bd) libère chaque nœud par l'allocateur du jeu ; le relais est dévié vers detach_nodes (behaviours.s, 0x142b2fd30), qui retire d'abord nos nœuds de .edata de leurs seaux (au plus 4096 pas par seau), sans quoi la libération de 0x153737598 plante en 0x1496fe904 (plantage de l'hôte du 2026-11-02) ; la table reconstruite par le jeu ne les contient plus, et la pose suivante les rajoute. Pose et retrait idempotents ; une version précédente en service est mise à jour sur place (fin du code, puis entrée de la table du fournisseur d'entité, puis ancienne fonction effacée) ; « retirer » remet les fabriques, retire nos nœuds et rétablit la comparaison et le relais du vidage (les substitutions restent en place, inutilisées) ; « etat » liste l'installation et les substitutions créées."""

import os
import struct
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "health"))
sys.path.insert(0, HERE)
from health_mirror import Process
import player_list

CODE_ADDRESS = 0x142B2F700
FACTORY, COMPARE_HOOK, ENTITY_EVALUATE, SPREAD_EVALUATE = CODE_ADDRESS, CODE_ADDRESS + 0x5C, CODE_ADDRESS + 0x5E0, CODE_ADDRESS + 0x2D6
DETACH_NODES = CODE_ADDRESS + 0x630
RESERVE, RESERVE_SIZE = CODE_ADDRESS + 0x2C8, 14
PROVIDER_TABLE, ENTITY_TABLE = CODE_ADDRESS + 0x5A0, CODE_ADDRESS + 0x5C0
PROVIDER, ENTITY, EMPTY_ARRAY, NODES = 0x153737500, 0x153737540, 0x153737570, 0x153737580
NODE_SIZE = 0x18
ADDED_SLOTS = {"MoveToLOS": 0, "MoveFromLOS": 1, "Flee": 2}
SUBSTITUTE_HEAD = 0x153737070
SUBSTITUTE_MAGIC = 0x4E4F4954554D4F43
FACTORY_TABLE, FACTORY_COUNT = 0x144326B38, 0x144326B40
STUB = 0x140463610
COMPARE_SITE = 0x146D4A8CA
COMPARE_ORIGINAL = bytes.fromhex("483958100f84b9000000")
CLEAR_THUNK, CLEAR = 0x14053C7B0, 0x146D56800
CLEAR_ORIGINAL = b"\xe9" + struct.pack("<i", CLEAR - (CLEAR_THUNK + 5))
CLEAR_JUMP = b"\xe9" + struct.pack("<i", DETACH_NODES - (CLEAR_THUNK + 5))
TRANSFORM_ENTITY_TYPE, AI_TARGET_TYPE, MOVE_TO_POINT_TYPE = 0x1452972A0, 0x1452801D0, 0x1451FD510
TYPES = {0x1451FD350: "CircleStrafe", 0x1451FCFD0: "SquadCircle", 0x1451FD3C0: "StayAtRange", 0x145280FD0: "MoveToLOS",
         0x145280EF0: "MoveFromLOS", 0x1451FD580: "MoveToTarget", 0x145281190: "Flee"}
CODE = bytearray(open(os.path.join(HERE, "behaviours.bin"), "rb").read())
struct.pack_into("<Q", CODE, PROVIDER_TABLE - CODE_ADDRESS + 0x18, SPREAD_EVALUATE)
struct.pack_into("<Q", CODE, ENTITY_TABLE - CODE_ADDRESS + 0x18, ENTITY_EVALUATE)
CODE = bytes(CODE)
LOS_CODE_ADDRESS, LOS_CODE_END = 0x142B34000, 0x142B38000
LOS_FACTORY, LOS_HEAD, LOS_COUNTERS = LOS_CODE_ADDRESS, 0x153737678, 0x153737680
LOS_NAMES = ("MoveToLOS", "MoveFromLOS", "Flee")
LOS_KINDS = ("MoveToLOS", "MoveFromLOS", "Flee")
with open(os.path.join(HERE, "lines_of_sight.bin"), "rb") as source:
    LOS_CODE = source.read()
COMPARE_JUMP = b"\xe9" + struct.pack("<i", COMPARE_HOOK - (COMPARE_SITE + 5)) + b"\x90" * 5
PROVIDER_OBJECT = struct.pack("<QQQQQQf", PROVIDER_TABLE, 0, TRANSFORM_ENTITY_TYPE, 0, 0, ENTITY, 0.0)
ENTITY_OBJECT = struct.pack("<QQQQQQ", ENTITY_TABLE, 0, AI_TARGET_TYPE, 0, 0, 0)


class Installation:
    def __init__(self, process: Process) -> None:
        self.process = process

    def write(self, address: int, data: bytes) -> None:
        self.process.memory.seek(address)
        self.process.memory.write(data)

    def buckets(self) -> tuple[int, int]:
        return self.process.qword(FACTORY_TABLE), struct.unpack("<I", self.process.read(FACTORY_COUNT, 4))[0]

    def nodes(self) -> dict[int, tuple[int, int, int]]:
        table, count = self.buckets()
        found = {}
        for bucket in range(count):
            previous, node = table + bucket * 8, self.process.qword(table + bucket * 8)
            for _ in range(256):
                if not node:
                    break
                identifier = struct.unpack("<H", self.process.read(node, 2))[0]
                found[identifier] = (node, previous, bucket)
                previous, node = node + 0x10, self.process.qword(node + 0x10)
        return found

    def identifiers(self) -> dict[int, str]:
        return {struct.unpack("<H", self.process.read(info + 0x38, 2))[0]: name for info, name in TYPES.items()}

    def install_line_of_sight(self) -> None:
        if LOS_CODE_ADDRESS + len(LOS_CODE) > LOS_CODE_END:
            sys.exit("lines_of_sight.bin trop long pour son emplacement")
        present = self.process.read(LOS_CODE_ADDRESS, len(LOS_CODE))
        if present == LOS_CODE:
            return
        if any(self.process.qword(node + 8) == LOS_FACTORY for node, _, _ in self.nodes().values()):
            sys.exit("autre version de lignes_de_vue en service : la retirer d'abord")
        if any(byte not in (0, 0xCC) for byte in present):
            sys.exit(f"emplacement de lignes_de_vue non vide ({LOS_CODE_ADDRESS:#x})")
        self.write(LOS_CODE_ADDRESS, LOS_CODE)
        self.write(LOS_HEAD, bytes(8 + 0x40))

    def install(self) -> list[str]:
        player_list.install(self.process)
        self.install_line_of_sight()
        present = self.process.read(CODE_ADDRESS, len(CODE))
        if present != CODE:
            replaced = set(range(RESERVE - CODE_ADDRESS, RESERVE - CODE_ADDRESS + RESERVE_SIZE)) | set(range(ENTITY_TABLE - CODE_ADDRESS + 0x18, ENTITY_TABLE - CODE_ADDRESS + 0x20))
            if any(old not in (new, 0xCC) for index, (old, new) in enumerate(zip(present, CODE)) if index not in replaced):
                sys.exit("emplacement du code non vide")
            table, reserve = ENTITY_TABLE - CODE_ADDRESS + 0x18, RESERVE - CODE_ADDRESS
            self.write(CODE_ADDRESS, CODE[:reserve])
            self.write(RESERVE + RESERVE_SIZE, CODE[reserve + RESERVE_SIZE:table])
            self.write(ENTITY_TABLE + 0x20, CODE[table + 8:])
            self.write(ENTITY_TABLE + 0x18, CODE[table:table + 8])
            self.write(RESERVE, CODE[reserve:reserve + RESERVE_SIZE])
        if self.process.read(PROVIDER, len(PROVIDER_OBJECT)) != PROVIDER_OBJECT:
            self.write(PROVIDER, PROVIDER_OBJECT)
            self.write(ENTITY, ENTITY_OBJECT)
            self.write(EMPTY_ARRAY, bytes(16))
            self.write(SUBSTITUTE_HEAD, bytes(8))
        site = self.process.read(COMPARE_SITE, len(COMPARE_ORIGINAL))
        if site == COMPARE_ORIGINAL:
            self.write(COMPARE_SITE, COMPARE_JUMP)
        elif site != COMPARE_JUMP:
            sys.exit(f"comparaison inattendue en {COMPARE_SITE:#x} : {site.hex()}")
        thunk = self.process.read(CLEAR_THUNK, len(CLEAR_ORIGINAL))
        if thunk == CLEAR_ORIGINAL:
            self.write(CLEAR_THUNK, CLEAR_JUMP)
        elif thunk != CLEAR_JUMP:
            sys.exit(f"relais du vidage inattendu en {CLEAR_THUNK:#x} : {thunk.hex()}")
        nodes, table, count = self.nodes(), *self.buckets()
        report = []
        for identifier, name in sorted(self.identifiers().items()):
            factory = LOS_FACTORY if name in LOS_NAMES else FACTORY
            if identifier in nodes:
                node = nodes[identifier][0]
                function = self.process.qword(node + 8)
                if function == factory:
                    report.append(f"{name} déjà posé")
                elif function in (STUB, FACTORY, LOS_FACTORY):
                    self.write(node + 8, struct.pack("<Q", factory))
                    report.append(f"{name} réécrit")
                else:
                    report.append(f"{name} laissé (fabrique {function:#x})")
                continue
            slot = ADDED_SLOTS.get(name)
            if slot is None:
                report.append(f"{name} absent de la table, non ajouté")
                continue
            node, head = NODES + slot * NODE_SIZE, table + (identifier % count) * 8
            self.write(node, struct.pack("<HHIQQ", identifier, 0, 0, factory, self.process.qword(head)))
            self.write(head, struct.pack("<Q", node))
            report.append(f"{name} ajouté")
        return report

    def uninstall(self) -> list[str]:
        report = []
        for identifier, (node, previous, _) in self.nodes().items():
            if self.process.qword(node + 8) not in (FACTORY, LOS_FACTORY):
                continue
            name = self.identifiers().get(identifier, hex(identifier))
            if NODES <= node < NODES + len(ADDED_SLOTS) * NODE_SIZE:
                self.write(previous, struct.pack("<Q", self.process.qword(node + 0x10)))
                self.write(node, bytes(NODE_SIZE))
                report.append(f"{name} retiré")
            else:
                self.write(node + 8, struct.pack("<Q", STUB))
                report.append(f"{name} remis au bouchon")
        if self.process.read(COMPARE_SITE, len(COMPARE_JUMP)) == COMPARE_JUMP:
            self.write(COMPARE_SITE, COMPARE_ORIGINAL)
            report.append("comparaison rétablie")
        if self.process.read(CLEAR_THUNK, len(CLEAR_JUMP)) == CLEAR_JUMP:
            self.write(CLEAR_THUNK, CLEAR_ORIGINAL)
            report.append("vidage de la table rétabli")
        return report

    def state(self) -> list[str]:
        nodes = self.nodes()
        lines = ["comparaison " + ("déviée" if self.process.read(COMPARE_SITE, len(COMPARE_JUMP)) == COMPARE_JUMP else "d'origine"),
                 "vidage de la table " + ("dévié" if self.process.read(CLEAR_THUNK, len(CLEAR_JUMP)) == CLEAR_JUMP else "d'origine")]
        for identifier, name in sorted(self.identifiers().items(), key=lambda item: item[1]):
            function = self.process.qword(nodes[identifier][0] + 8) if identifier in nodes else 0
            lines.append(f"{name} : " + ("notre fabrique" if function == FACTORY else "lignes de vue" if function == LOS_FACTORY else "bouchon" if function == STUB else "absent" if not function else f"{function:#x}"))
        entry = self.process.qword(SUBSTITUTE_HEAD)
        for _ in range(4096):
            if not entry or self.process.qword(entry + 0x80) != SUBSTITUTE_MAGIC:
                break
            original, distance, style = struct.unpack("<QfI", self.process.read(entry + 0x70, 0x10))
            lines.append(f"substitution {entry:#x} : {TYPES.get(original, hex(original))}, portée {distance:.1f} m, style {style}, orientation {self.process.read(entry + 0x50, 4)[0]}")
            entry = self.process.qword(entry + 0x88)
        entry = self.process.qword(LOS_HEAD)
        for _ in range(4096):
            if not entry or self.process.qword(entry + 0x80) != SUBSTITUTE_MAGIC:
                break
            kind, count, _, distance, safe, force, default = struct.unpack("<IIIffBB", self.process.read(entry + 0xE0, 0x16))
            detail = f"SafeDistance {safe:.1f} m" if kind == 2 else f"{count} points, repli {'oui' if default else 'non'}" + (f", portée {distance:.1f} m, même avec vue {'oui' if force else 'non'}" if kind == 0 else "")
            lines.append(f"lignes de vue {entry:#x} : {LOS_KINDS[kind] if kind < 3 else kind}, {detail}, style {self.process.read(entry + 0x7C, 4)[0]}")
            entry = self.process.qword(entry + 0x88)
        evaluations, searches, deferred, rays, found, fallback, stay = self.counters()[:7]
        lines.append(f"lignes de vue : {evaluations} évaluations, {searches} recherches, {deferred} reportées (une recherche par image), {rays} rayons, "
                     f"{found} points trouvés, {fallback} replis, {stay} sur place")
        return lines

    def counters(self) -> tuple:
        return struct.unpack("<7I4xQQQQ", self.process.read(LOS_COUNTERS, 0x40))

    def measure(self, seconds: float) -> list[str]:
        self.write(LOS_COUNTERS + 0x28, bytes(8))
        first = self.counters()
        time.sleep(seconds)
        last = self.counters()
        searches, rays, cycles = (last[i] - first[i] for i in (1, 3, 7))
        (tsc0, clock0), (tsc1, clock1) = (struct.unpack("<Qd", struct.pack("<QQ", c[9], c[10])) for c in (first, last))
        frequency = (tsc1 - tsc0) / (clock1 - clock0) if tsc0 and clock1 > clock0 and tsc1 > tsc0 else 0.0
        microseconds = (lambda value: f"{value / frequency * 1e6:.0f} µs") if frequency else (lambda value: f"{value} cycles")
        lines = [f"sur {seconds:.0f} s : {rays / seconds:.1f} rayons/s, {(last[0] - first[0]) / seconds:.2f} évaluations/s, {searches / seconds:.2f} recherches/s, {(last[2] - first[2]) / seconds:.2f} reportées/s, "
                 f"{last[4] - first[4]} points trouvés, {last[5] - first[5]} replis, {last[6] - first[6]} sur place"]
        if searches:
            lines.append(f"temps par recherche : moyen {microseconds(cycles / searches)}, maximal {microseconds(last[8])}, {rays / searches:.1f} rayons"
                         + (f" ; horloge TSC {frequency / 1e9:.2f} GHz" if frequency else " (horloge TSC non étalonnée)"))
        return lines


def main() -> None:
    pid, action = int(sys.argv[1]), sys.argv[2]
    installation = Installation(Process(pid))
    if action == "poser":
        print("posé : " + ", ".join(installation.install()))
    elif action == "retirer":
        print("retiré : " + (", ".join(installation.uninstall()) or "rien à retirer"))
    elif action == "etat":
        print("\n".join(installation.state()))
    elif action == "mesurer":
        print("\n".join(installation.measure(float(sys.argv[3]) if len(sys.argv) > 3 else 30.0)))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
