const ip = document.getElementById("ip");
const lan = document.getElementById("lan");
const play = document.getElementById("jouer");
const stop = document.getElementById("arreter");
const secondGame = document.getElementById("second");
const stopSecond = document.getElementById("arreter-second");
const state = document.getElementById("etat");
const journal = document.getElementById("journal");
const gameFolder = document.getElementById("dossier-jeu");
const changeFolder = document.getElementById("changer-dossier");
const modes = [...document.querySelectorAll("input[name=mode]")];

const selectedMode = () => modes.find((input) => input.checked)?.value ?? "local";

function refreshMode() {
  ip.disabled = selectedMode() !== "serveur";
}

function append(text) {
  journal.textContent += `${text}\n`;
  journal.scrollTop = journal.scrollHeight;
}

const showFolder = (folder) => { gameFolder.textContent = folder ?? "not found"; };

modes.forEach((input) => input.addEventListener("change", refreshMode));
changeFolder.addEventListener("click", async () => showFolder(await window.lanceur.dossierJeu()));
play.addEventListener("click", () => window.lanceur.jouer(selectedMode(), ip.value));
secondGame.addEventListener("click", () => window.lanceur.second());
stop.addEventListener("click", () => window.lanceur.arreter("jeu1"));
stopSecond.addEventListener("click", () => window.lanceur.arreter("jeu2"));
window.lanceur.surJournal(append);
window.lanceur.surEtat(({ localServer, localServerReady, patches, game, second, ready }) => {
  play.disabled = patches || game;
  changeFolder.disabled = game;
  secondGame.disabled = !ready || second;
  stop.disabled = !patches && !game;
  stopSecond.disabled = !second;
  state.textContent = [game ? "Game running" : patches ? "Starting…" : localServer && !localServerReady ? "Starting the local server…" : "Ready", localServerReady ? "local server running" : "", second ? "second game running" : ""].filter(Boolean).join(", ");
});

window.lanceur.choix().then(({ mode, modes: available, gameFolder: folder, ip: address, lan: lanAddress, redirector }) => {
  modes.forEach((input) => { input.closest("label").hidden = !available.includes(input.value); });
  showFolder(folder);
  document.getElementById("choix-mode").hidden = available.length === 1;
  document.getElementById("ligne-second").hidden = !available.includes("dev");
  const chosen = available.includes(mode) ? mode : "local";
  modes.forEach((input) => { input.checked = input.value === chosen; });
  ip.value = address;
  lan.textContent = lanAddress ? `(${lanAddress})` : "";
  refreshMode();
  state.textContent = `Ready (current redirector: ${redirector ?? "none"})`;
});
