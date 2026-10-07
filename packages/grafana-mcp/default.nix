{
  curl,
  lib,
  libsecret,
  mcp-grafana,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "grafana-mcp";
  meta.description = "Run mcp-grafana with a service account token from the user keyring";
  runtimeInputs = [
    curl
    libsecret
    mcp-grafana
  ];
  text = lib.readFile ./script.bash;
}
