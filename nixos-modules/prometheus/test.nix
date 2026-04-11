{ ... }:
{
  # Note: This extends the default configuration from ${self}/checks/nixos-modules
  nodes.server =
    { ... }:
    {
      qois.prometheus = {
        enable = true;
      };
    };
}
