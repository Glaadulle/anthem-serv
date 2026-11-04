"""Usage : python3 -I reactions.py PID {poser|retirer|etat} : rend aux ennemis leur réaction aux dégâts côté client, dont l'animation de mort et le ragdoll. Une mort d'ennemi est une réaction de force Death (7 à 9, action 52 FullBody, timeline de mort des bases HitReactions) que ClientDamageReactionComponent (vfa0 0x148b2f4e0) ne choisit qu'à la réception de DylanHealthComponentOnDamageMessage (0x84e38c29) quand la copie cliente n'a plus de vie (logique vf50 → personnage client +0x130 vf20 → santé cliente vf168, vie > 0). Ce message n'existe côté client que par un ApplyDamage client (0x140c15020 sur la copie), que les tirs ordinaires ne font pas sur le serveur interne, et le serveur ne transmet aucune réaction : ServerDamageReactionComponent a son gestionnaire de messages (0x143a88720 vfa0) et sa logique (0x143a888a0 vf80) à `ret 0`, et l'état réseau du composant client n'est qu'un bit (lecteur 0x148b33120). Le correctif dévie l'appel de la mise à jour de la vie répliquée (0x148b3711c, call 0x140cba3a0 dans le lecteur réseau client 0x148b36f00) vers reactions.s (0x142b35200) : après la mise à jour d'origine (état, agonie, mort, OnKilled client), si la copie est celle d'une IA (table 0x143a8d310) et que sa vie a baissé, il construit une DylanDamageInfo (0x1408f09d0, montant +0xd0 = vie perdue, détruite par 0x1408f0b70) et un résultat (+4 vie perdue, +0x35 appliqué, +0x36 vie touchée), puis envoie le message aux composants de l'entité (drapeau 0x800, vfa0), comme 0x140c15020. Garde (plantage du 2026-11-03, data/crash_seh.log) : une réaction jouée (0x140c10cf0) envoie 0x19c742a6 aux composants de l'entité ; ClientDylanCharacterSimulationComponent (vfa0 0x140bcd8c0 → 0x14888f520) le passe à son sous-objet +0xe0 (0x1480c8280), qui appelle sans test 0x1408996f0 sur le porteur de contexte [composant+0x1b18] (base virtuelle, [[sous-objet+0x10]+4] + 0x98) ; s'il est nul, rien n'est envoyé. Fil client, à la réception de la réplication."""

import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from health_mirror import Process

CODE_ADDRESS = 0x142B35200
CODE = open(os.path.join(HERE, "reactions.bin"), "rb").read()
CALL_SITE = 0x148B3711C
ORIGINAL = 0x140CBA3A0


def call_to(target: int) -> bytes:
    return b"\xe8" + struct.pack("<i", target - (CALL_SITE + 5))


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    process, action = Process(int(sys.argv[1])), sys.argv[2]
    current = process.read(CALL_SITE, 5)
    if action == "etat":
        state = "réactions" if current == call_to(CODE_ADDRESS) else "origine" if current == call_to(ORIGINAL) else f"inattendu {current.hex()}"
        print(f"mise à jour de la vie répliquée -> {state}")
    elif action == "poser":
        if current not in (call_to(ORIGINAL), call_to(CODE_ADDRESS)):
            sys.exit(f"appel inattendu {current.hex()}")
        present = process.read(CODE_ADDRESS, len(CODE))
        if present != CODE:
            if current == call_to(CODE_ADDRESS):
                sys.exit("ancienne version du code en service : retirer d'abord")
            if set(present) != {0xCC} and not present.startswith(CODE[:8]):
                sys.exit("emplacement du code non vide")
            process.write(CODE_ADDRESS, CODE)
        process.write(CALL_SITE, call_to(CODE_ADDRESS))
        print(f"posé : réactions aux dégâts répliqués -> {CODE_ADDRESS:#x}")
    elif action == "retirer":
        if current == call_to(CODE_ADDRESS):
            process.write(CALL_SITE, call_to(ORIGINAL))
        print("retiré")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
