{
  gitMinimal,
  lib,
  openssh,
  self,
  system,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "qois-disk-unlock";
  meta.description = "Unlock a host's encrypted disks through its initrd ssh server";
  runtimeInputs = [
    gitMinimal
    openssh
    self.packages.${system}.sops
  ];
  text = lib.readFile ./script.bash;
}
