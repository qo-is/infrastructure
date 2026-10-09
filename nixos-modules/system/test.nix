{ pkgs, ... }:
let
  inherit (import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs)
    snakeOilPrivateKey
    snakeOilPublicKey
    ;
in
{
  nodes = {
    server =
      { ... }:
      {
        users.users.root.openssh.authorizedKeys.keys = [ snakeOilPublicKey ];
      };

    client =
      { ... }:
      {
        environment.etc."ssh-test-key" = {
          source = snakeOilPrivateKey;
          mode = "0600";
        };
      };
  };
}
