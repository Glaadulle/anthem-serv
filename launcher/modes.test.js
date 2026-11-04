const test = require("node:test");
const assert = require("node:assert");
const { availableModes, isLocal, localServerEnv, patchesEnv } = require("./modes");

test("le mode dev et le mode local lancent le serveur sur ce PC, pas le serveur dédié", () => {
  assert.equal(isLocal("local"), true);
  assert.equal(isLocal("dev"), true);
  assert.equal(isLocal("serveur"), false);
});

test("le mode dev active le hub partagé et l'escouade automatique du serveur local", () => {
  assert.deepEqual(localServerEnv("dev"), { BINAIRES: "target/debug", BLAZE_HUB_PARTAGE: "1", BLAZE_ESCOUADE_AUTO: "1" });
  assert.deepEqual(localServerEnv("local"), { BINAIRES: "target/debug" });
});

test("le mode dev passe le hub partagé aux correctifs du jeu", () => {
  assert.deepEqual(patchesEnv("dev", "192.168.1.115"), { SERVEUR_CENTRAL: "192.168.1.115", HUB_PARTAGE: "1" });
  assert.deepEqual(patchesEnv("local", "192.168.1.115"), { SERVEUR_CENTRAL: "192.168.1.115" });
  assert.deepEqual(patchesEnv("serveur", "192.168.1.53"), { SERVEUR_CENTRAL: "192.168.1.53" });
});

test("les modes proposés sont ceux de modes.json, tous sans ce fichier", () => {
  assert.deepEqual(availableModes(null), ["local", "dev", "serveur"]);
  assert.deepEqual(availableModes('["local"]'), ["local"]);
  assert.deepEqual(availableModes('["serveur", "inconnu"]'), ["serveur"]);
  assert.deepEqual(availableModes("illisible"), ["local", "dev", "serveur"]);
  assert.deepEqual(availableModes("[]"), ["local", "dev", "serveur"]);
});
