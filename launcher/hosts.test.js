const test = require("node:test");
const assert = require("node:assert");
const { redirectorAddress, withRedirector } = require("./hosts");

const NAME = "spring18.gosredirector.ea.com";

test("lit l'adresse du redirector", () => {
  assert.equal(redirectorAddress(`127.0.0.1 localhost\n192.168.1.53 ${NAME}\n`), "192.168.1.53");
  assert.equal(redirectorAddress("127.0.0.1 localhost\n"), null);
});

test("remplace toutes les lignes du redirector par une seule", () => {
  const text = `127.0.0.1 localhost\n127.0.0.1 ${NAME}\n127.0.0.1 ${NAME}\n`;
  assert.equal(withRedirector(text, "192.168.1.53"), `127.0.0.1 localhost\n192.168.1.53 ${NAME}\n`);
});

test("ajoute la ligne si elle manque, sans toucher au reste", () => {
  const text = "# commentaire\n127.0.0.1 localhost";
  assert.equal(withRedirector(text, "127.0.0.1"), `# commentaire\n127.0.0.1 localhost\n127.0.0.1 ${NAME}\n`);
});

test("ignore une ligne commentée", () => {
  assert.equal(redirectorAddress(`# 10.0.0.1 ${NAME}\n`), null);
});

test("refuse une adresse invalide", () => {
  assert.throws(() => withRedirector("", "192.168.1"), /not an IPv4 address/);
  assert.throws(() => withRedirector("", "1.2.3.4; rm"), /not an IPv4 address/);
});
