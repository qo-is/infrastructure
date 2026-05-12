# Switch lindberg to systemd-networkd — Manual Verification

After deploying the networkd migration, run these checks on lindberg.

## Deploy

```bash
nix develop
deploy --skip-checks .#lindberg.system-physical
```

## Checks

### 1. networkd is managing interfaces

```bash
networkctl list
```

Expected: `enp5s0` and `vms-nat` have `SETUP = configured`, carrier and admin state shown.
`wg-backplane` should appear as `unmanaged` (still scripted).

### 2. vms-nat has its static IP (no VMs required)

```bash
ip addr show vms-nat
```

Expected: `inet 10.247.0.1/24` present — confirms `ConfigureWithoutCarrier` is working.

### 3. dnsmasq started cleanly

```bash
systemctl status dnsmasq
```

Expected: `Active: active (running)`. If it failed to bind, the IP on vms-nat is missing.

### 4. VPN / backplane connectivity still works

```bash
ping 10.250.0.6   # calanda
ping 10.250.0.9   # cyprianspitz
```

Confirms wgautomesh connected peers after staying on scripted wireguard backend.

### 5. VM NAT still works (from a running VM)

From a VM connected to vms-nat:

```bash
curl -s https://1.1.1.1 --max-time 5
```

Confirms NAT masquerade via `enp5s0` still works.

### 6. Load balancer / public services reachable

```bash
curl -sk https://cloud.qo.is | head -5
```

Confirms HAProxy + backplane routing to lindberg-nextcloud is intact.

### 7. Check journal for networkd errors

```bash
journalctl -u systemd-networkd --since boot | grep -i "error\|fail\|warning" | head -20
```
