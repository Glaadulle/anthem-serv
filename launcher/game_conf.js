const quoted = (text) => `'${text.replaceAll("'", "'\\''")}'`;

function withGameExe(conf, exe, home) {
  const written = exe.startsWith(`${home}/`) ? `~/${exe.slice(home.length + 1)}` : exe;
  const others = conf.split("\n").filter((line) => line && !line.startsWith("JEU_EXE="));
  return [...others, `JEU_EXE=${quoted(written)}`].join("\n") + "\n";
}

module.exports = { withGameExe };
