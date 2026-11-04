const test = require("node:test");
const assert = require("node:assert");
const { withGameExe } = require("./game_conf");

test("le chemin du jeu sous le dossier personnel est écrit relatif à ~", () => {
  assert.equal(withGameExe("", "/maison/Jeux/Anthem/Anthem.exe", "/maison"), "JEU_EXE='~/Jeux/Anthem/Anthem.exe'\n");
});

test("la ligne JEU_EXE est remplacée, les autres réglages gardés", () => {
  const conf = "PROTON=~/proton\nJEU_EXE=ancien/Anthem.exe\n";
  assert.equal(withGameExe(conf, "/disque/Anthem/Anthem.exe", "/maison"), "PROTON=~/proton\nJEU_EXE='/disque/Anthem/Anthem.exe'\n");
});

test("une apostrophe du chemin reste lisible par bash", () => {
  assert.equal(withGameExe("", "/disque/l'Anthem/Anthem.exe", "/maison"), "JEU_EXE='/disque/l'\\''Anthem/Anthem.exe'\n");
});
