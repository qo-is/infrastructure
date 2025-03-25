# Host: Cyprianspitz

## Operations {#\_operations}

Reboot requires passphrase.

```bash
# Get HDD Password:
sops decrypt --extract '["system"]["hdd"]' private/nixos-configurations/cyprianspitz/secrets.sops.yaml

ssh -p 8223 root@calanda.plessur-ext.net.qo.is
```

Direct remote ssh access:

```
ssh -p 8222 root@calanda.plessur-ext.net.qo.is
```

## Hardware

TODO

- [Mainboard Manual](docs/z790m-itx-wifi.pdf)

### Top Overview

![](docs/top-view.jpg)

### PCIE Side

![](docs/pcie-side.jpg)

### HDD Bay

Note that the slot in the middle of the SATA bay is not connected due to the mainboard only having 4 SATA plugs.
