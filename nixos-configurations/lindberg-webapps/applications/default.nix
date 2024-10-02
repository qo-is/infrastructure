{ config, pkgs, ... }:
{

  imports = [ ];

  qois.vault.enable = true;
  qois.git.enable = true;
  qois.static-page.enable = true;
}
