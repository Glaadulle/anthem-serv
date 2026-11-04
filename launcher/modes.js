const MODES = ["local", "dev", "serveur"];

function availableModes(text) {
  try {
    const chosen = MODES.filter((mode) => JSON.parse(text).includes(mode));
    return chosen.length ? chosen : MODES;
  } catch {
    return MODES;
  }
}

const isLocal = (mode) => mode === "local" || mode === "dev";

const localServerEnv = (mode) =>
  mode === "dev" ? { BINAIRES: "target/debug", BLAZE_HUB_PARTAGE: "1", BLAZE_ESCOUADE_AUTO: "1" } : { BINAIRES: "target/debug" };

const patchesEnv = (mode, address) => (mode === "dev" ? { SERVEUR_CENTRAL: address, HUB_PARTAGE: "1" } : { SERVEUR_CENTRAL: address });

module.exports = { availableModes, isLocal, localServerEnv, patchesEnv };
