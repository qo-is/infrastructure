# Host: Cyprianspitz (+Router: Caral)

## Operations {#_operations}

Reboot requires passphrase.

``` bash
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


### Networking: Caral Internet Router

A [MikroTik `CCR2004-1G-2XS-PCIe`](https://mikrotik.com/product/ccr2004_1g_2xs_pcie#fndtn-downloads) is used for internet access.
It's a fiber card with build in router, supporting 2x 25Gbit SFP28 cages and 1Gbit RJ45 eth.

- [RouterOS Docs](https://help.mikrotik.com/docs/spaces/ROS/pages/328059/RouterOS)

[The manual](docs/CCR2004-1G-2XS-PCIe_241138.pdf) states:

> This form-factor does come with certain limitations that you should keep in mind.
> The CCR NIC card needs some time to boot up compared to ASIC-based setups.
> If the host system is up before the CCR card, it will not appear among the available devices.
> You should add a PCIe device initialization delay after power-up in the BIOS.
> Or you will need to re-initialize the PCIe devices from the HOST system.

In our case, since networking is reinitialized after the LUKS password promt, this should not be a issue in practice. However, if networking would not be available, contact someone for a physical reboot and wait longer before entering the HDD password.

To reload the card's virtual interfaces on a running system:

```bash
echo "1" > /sys/bus/pci/devices/0000\:01\:00.0/remove
sleep 2
echo "1" > /sys/bus/pci/rescan
```

To restart the card on a running system:

```bash
echo "1" > /sys/bus/pci/devices/0000\:01\:00.0/reset
sleep 2m # Wait for reboot
echo "1" > /sys/bus/pci/rescan
```

### Top Overview

![](docs/top-view.jpg)

### PCIE Side

![](docs/pcie-side.jpg)

### HDD Bay

Note that the slot in the middle of the SATA bay is not connected due to the mainboard only having 4 SATA plugs.
