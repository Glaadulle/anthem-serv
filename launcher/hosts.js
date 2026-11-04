const REDIRECTOR = "spring18.gosredirector.ea.com";
const IPV4 = /^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}$/;

function redirectorLine(line) {
  const fields = line.trim().split(/\s+/);
  return !line.trim().startsWith("#") && fields.slice(1).includes(REDIRECTOR) ? fields[0] : null;
}

function redirectorAddress(text) {
  return text.split("\n").map(redirectorLine).find((address) => address) ?? null;
}

function withRedirector(text, address) {
  if (!IPV4.test(address)) throw new Error(`${address} is not an IPv4 address`);
  const kept = text.split("\n").filter((line) => !redirectorLine(line));
  while (kept.length && kept[kept.length - 1] === "") kept.pop();
  return `${[...kept, `${address} ${REDIRECTOR}`].join("\n")}\n`;
}

module.exports = { REDIRECTOR, IPV4, redirectorAddress, withRedirector };
