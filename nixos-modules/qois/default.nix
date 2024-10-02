{
  config,
  pkgs,
  inputs,
  ...
}:
{

  imports = inputs.self.lib.loadSubmodulesFrom ./.;
}
