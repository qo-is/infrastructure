# Services

This folder contains services configurations, that run on top of the platform.

## Structure

A service may consist of one or more of the following:

Required files:

- **`service.nix`**: Configuration of the *platform* for this service.
- **`module.nix`**: NixOS module of this service.
  - Must be `enable = false` by default
  - May expose options for other services
- **`config/`**: Configuration of `module.nix` for
  - `prod.nix`: Production system
  - `local.nix`: Running the service locally
  - `check.nix`: Running the service as part of tests.

Optional files:

- **`config-other-services/<env>.nix`**: Configuration of related services, as defined in another `module.nix`.
  Example: databases to be created by postgres.

## Testing

TODO: All services should have tests, and they should be fast and robust.
