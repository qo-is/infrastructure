# TODO: This is the configuration for lindberg and should be moved to lindberg host config.

{ ... }:
{
  qois.storage = {
    hot.mountpoint = "/mnt/ssd"; # TODO: Share config with disko.
    cool.mountpoint = "/mnt/data"; # TODO: Share config with disko.
  };
}
