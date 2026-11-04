"""Usage : python3 -I tools/damage_editor.py [URL_BIGS] [PORT] : sert sur http://127.0.0.1:PORT (8091 par défaut) une page qui liste les dégâts des armes de la table de BIGS (route /editeur/degats, fichier data/game/weapon_damage.json) : arme, statistique, valeur d'origine et valeur réglée ; l'enregistrement envoie les valeurs modifiées à BIGS, qui les sert en réglages (GET /api/gameconfig/tuning), lus par le jeu à la connexion suivante. Sans BIGS, la page lit et écrit directement la table (data/game/weapon_damage.json), pour régler les armes avant de jouer : BIGS la charge à son démarrage."""

import http.server
import json
import os
import sys
import urllib.request

DEFAULT_BIGS = "http://127.0.0.1:8080"
DEFAULT_TABLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "game", "weapon_damage.json")
DEFAULT_PORT = 8091

PAGE = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><title>Dégâts des armes</title>
<style>
body{font:14px system-ui,sans-serif;margin:0;padding:16px 24px;background:#14171c;color:#e6e6e6}
h1{font-size:20px;margin:0 0 4px}p.aide{color:#9aa3ad;margin:0 0 16px}
table{width:100%;border-collapse:collapse}th,td{padding:4px 12px;border-top:1px solid #23292f;text-align:left}
td.nom{font-family:monospace}input{width:7em}button{background:#2d6cdf;color:#fff;border:0;border-radius:4px;padding:5px 10px;cursor:pointer}
#barre{position:sticky;top:0;background:#14171c;padding:8px 0;display:flex;gap:12px;align-items:center}
#etat{color:#9aa3ad}tr.modifie td{background:#2a2410}tr.inactif td{color:#6b737c}
</style></head><body>
<h1>Dégâts des armes</h1>
<p class="aide">Valeurs servies par BIGS en réglages au démarrage du jeu. Une ligne grisée n'est pas réglable : la disposition de sa classe n'a pas été relevée.</p>
<div id="barre"><button id="enregistrer">Enregistrer</button><span id="etat"></span></div>
<table><thead><tr><th>Arme</th><th>Statistique</th><th>Origine</th><th>Réglée</th></tr></thead><tbody id="lignes"></tbody></table>
<script>
let lignes = [];
function marquer() {
  let changes = 0;
  document.querySelectorAll("tr[data-index]").forEach(tr => {
    const modifie = Number(tr.querySelector("input").value) !== lignes[tr.dataset.index].reglee;
    tr.classList.toggle("modifie", modifie);
    changes += modifie;
  });
  document.getElementById("etat").textContent = changes ? `${changes} modification(s) non enregistrée(s)` : "";
}
async function charger() {
  lignes = await (await fetch("/degats")).json();
  document.getElementById("lignes").innerHTML = lignes.map((l, i) =>
    `<tr data-index="${i}" class="${l.reglable ? "" : "inactif"}"><td class="nom">${l.arme.split("/").pop()}</td><td>${l.stat}</td>` +
    `<td>${l.origine}</td><td><input type="number" step="any" value="${l.reglee}" ${l.reglable ? "" : "disabled"}></td></tr>`).join("");
  document.querySelectorAll("tr[data-index] input").forEach(input => input.addEventListener("input", marquer));
  marquer();
}
document.getElementById("enregistrer").addEventListener("click", async () => {
  const changes = [...document.querySelectorAll("tr.modifie")].map(tr => {
    const l = lignes[tr.dataset.index];
    return {arme: l.arme, stat: l.stat, reglee: Number(tr.querySelector("input").value)};
  });
  if (!changes.length) { document.getElementById("etat").textContent = "Rien à enregistrer"; return; }
  const reponse = await fetch("/degats", {method: "POST", headers: {"content-type": "application/json"}, body: JSON.stringify(changes)});
  await charger();
  document.getElementById("etat").textContent = reponse.ok ? `${changes.length} valeur(s) enregistrée(s)` : "Erreur à l'enregistrement";
});
charger();
</script></body></html>
"""


def file_rows(path: str) -> list:
    """Lignes de l'éditeur lues dans la table, comme les sert BIGS (WeaponDamage::editor_rows)."""
    with open(path) as handle:
        rows = json.load(handle)
    return [{"arme": row["arme"], "stat": row["stat"], "origine": row["origine"], "reglee": row["reglee"],
             "reglable": isinstance(row.get("fieldOffset"), int) and isinstance(row.get("typeId"), int)} for row in rows]


def file_adjust(path: str, changes: list) -> list:
    with open(path) as handle:
        rows = json.load(handle)
    for change in changes:
        for row in rows:
            if row["arme"] == change["arme"] and row["stat"] == change["stat"]:
                row["reglee"] = change["reglee"]
    temporary = path + ".tmp"
    with open(temporary, "w") as handle:
        json.dump(rows, handle, indent=2, ensure_ascii=False)
    os.replace(temporary, path)
    return rows


def damage_rows(bigs: str, path: str) -> tuple[list, str]:
    try:
        return bigs_damage(bigs), "BIGS"
    except OSError:
        return file_rows(path), "fichier"


def bigs_damage(bigs: str, changes: list | None = None) -> list:
    body = None if changes is None else json.dumps(changes).encode()
    request = urllib.request.Request(f"{bigs}/editeur/degats", data=body, method="GET" if body is None else "PUT",
                                     headers={"content-type": "application/json"})
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read())


class Editor(http.server.BaseHTTPRequestHandler):
    bigs = DEFAULT_BIGS
    table = DEFAULT_TABLE

    def reply(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def reply_json(self, status: int, value) -> None:
        self.reply(status, "application/json; charset=utf-8", json.dumps(value).encode())

    def do_GET(self) -> None:
        if self.path == "/":
            self.reply(200, "text/html; charset=utf-8", PAGE.encode())
        elif self.path == "/degats":
            try:
                self.reply_json(200, damage_rows(self.bigs, self.table)[0])
            except OSError as error:
                self.reply_json(502, {"erreur": f"BIGS injoignable et table illisible : {error}"})
        else:
            self.reply(404, "text/plain", b"")

    def do_POST(self) -> None:
        if self.path != "/degats":
            self.reply(404, "text/plain", b"")
            return
        changes = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))))
        valid = [change for change in changes if isinstance(change.get("reglee"), (int, float)) and change["reglee"] >= 0]
        if len(valid) != len(changes):
            self.reply_json(400, {"erreur": "valeurs positives attendues"})
            return
        try:
            self.reply_json(200, bigs_damage(self.bigs, valid))
        except OSError:
            try:
                file_adjust(self.table, valid)
                self.reply_json(200, file_rows(self.table))
            except OSError as error:
                self.reply_json(502, {"erreur": f"BIGS injoignable et table non écrite : {error}"})

    def log_message(self, format: str, *arguments) -> None:
        pass


def main() -> None:
    Editor.bigs = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_BIGS
    port = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_PORT
    print(f"éditeur des dégâts : http://127.0.0.1:{port} (BIGS {Editor.bigs})")
    http.server.ThreadingHTTPServer(("127.0.0.1", port), Editor).serve_forever()


if __name__ == "__main__":
    main()
