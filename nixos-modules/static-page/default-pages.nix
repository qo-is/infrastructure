{
  lib,
  ...
}:
{

  qois.static-page.pages = lib.mkDefault {
    "fabianhauser.ch" = {
      domainAliases = [
        "www.fabianhauser.ch"
        "fabianhauser.nl"
        "www.fabianhauser.nl"
        "www.fh2.ch"
        "fh2.ch"
      ];
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFsSCoClNpgW7x6YngP/CEFbyR8GEJ3V8NdUFvZ/6lj6 ci@git.qo.is"
      ];
    };
    "docs-ops.qo.is".authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBS65v7n5ozOUjYGuO/dgLC9C5MUGL5kTnQnvWAYP5B3 ci@git.qo.is"
    ];
    "qo.is" = {
      domainAliases = [
        "www.qo.is"
      ];
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMG6xYcf7+l1RDPB7XcLxTvb6CqkaKqEGGb529Qk3b5T ci@git.qo.is"
      ];
    };
  };
}
