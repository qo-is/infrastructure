# defaults

## Overview

Static defaults shared by all hosts: hardware profiles imported by host configurations and the `qois.meta` host and network metadata imported by [nixos-modules](../nixos-modules/EGM.md).

## Subdirectories & Boundaries

- hardware: [./hardware/EGM.md](./hardware/EGM.md) - Hardware profile modules (APU, APU1, Asrock Z790M, Asrock X570) setting initrd modules, KVM, microcode, `max-jobs` and APU serial console
- meta: [./meta/EGM.md](./meta/EGM.md) - `qois.meta` values: hosts from `hosts.json`, physical networks and virtual networks (backplane, VPN, VM NAT)
