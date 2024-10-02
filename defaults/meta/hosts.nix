{ ... }:
{
  qois.meta.hosts = builtins.fromJSON (builtins.readFile ./hosts.json);
}
