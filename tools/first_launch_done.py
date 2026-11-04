"""Usage : python3 -I tools/first_launch_done.py ProfileOptions : passe l'option FirstBoot à 0 pour ne plus afficher les options de premier lancement (jeu fermé)."""

import pathlib
import shutil
import sys

FIRST_BOOT_ENTRY = b"FirstBoot\x00\x02\x00\x00\x00"


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = pathlib.Path(sys.argv[1])
    data = bytearray(path.read_bytes())
    entry = data.find(FIRST_BOOT_ENTRY)
    if entry < 0:
        sys.exit("option FirstBoot introuvable : format du fichier inattendu")
    value = entry + len(FIRST_BOOT_ENTRY)
    if data[value : value + 2] == b"0\x00":
        print("FirstBoot déjà à 0")
        return
    if data[value : value + 2] != b"1\x00":
        sys.exit(f"valeur de FirstBoot inattendue : {bytes(data[value : value + 2])!r}")
    shutil.copy2(path, path.with_name(path.name + ".avant-firstboot"))
    data[value] = ord("0")
    path.write_bytes(data)
    print("FirstBoot passé à 0")


if __name__ == "__main__":
    main()
