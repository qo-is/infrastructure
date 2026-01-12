# Platform

> The platform provides the neccesary core infrastructure so that services can focus on their applications.

It is hardware- and service agnostic, i.e. the platform doesn't have a direct dependency on either.

It's implemented as NixOS Modules.

Concretely:

### *comp*: Compute

> The bridge between the hardware and services.

- Manage computing ressources (CPU, GPU, Memory etc.)
- Hardware passthrough
- Service isolation with virtualisation

### *net*: Networking

> Connectivity between the outside world and servies, and between services.

Not part of platform: user VPN.

### *o11y*: Observability

> Understand the current state of the platform and services.

### *persist*: Persistance

> Store data permanently, safely and as fast as required.

- Nix Store
- File Storage
- Backups

Not part of platform: databases (at this time)

### *sec*: Security

> Make sure services and users can only do what they should.

- Authentication and authorisation (users and services)
- Firewalling
- Secrets

Not part of platform: application security.
