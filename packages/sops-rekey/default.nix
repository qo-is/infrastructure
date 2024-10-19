{
  findutils,
  self,
  system,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "sops-rekey";
  meta.description = "Rekey all sops secrets with changed keys";
  runtimeInputs = [
    findutils
    self.packages.${system}.sops
  ];
  text = ''
    find . -regex '.*\.sops\..*$' -type f -exec sops updatekeys {} \;
  '';
}
