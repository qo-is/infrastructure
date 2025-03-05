# VPN

On [vpn.qo.is](https://vpn.qo.is) we run a [Tailscale](https://tailscale.com) compatible VPN service. To use the service, you can use a normal Tailscale client with following additional configuration:

| Option | Recommended value | Description |
|--------|-------------------|-------------|
| `accept-routes` | enabled (flag) | Accept direct routes to internal services |
| `exit-node` | `100.64.0.5` (lindberg) or `100.64.0.6` (cypriaspitz) | Use host as [exit node](#exit-nodes) |
| `login-server` | `https://vpn.qo.is` | Use our own VPN service and not tailscale's upstream one |


⚠️  Currently, if the client is in an IPv6 network, the transport is broken. See [#4](https://git.qo.is/qo.is/infrastructure/issues/4) for progress on this.

## Exit nodes

- `100.64.0.5`: lindberg (riedbach-net)
- `100.64.0.6`: cyprianspitz (plessur-net)

Currently, name resolution for these do not work reliably on first starts, hence the IP must be used. This hould be fixed in the future.

## User and Client Management

To register a new client, you can generate a pre-auth key and insert it in the client:

```bash
headscale preauthkeys create --user marlene.mayer
```

Or alternatively use the register command shown when configuring the VPN client.

## ACL

At this time, there are a few ACL rules to isolate a users host but do not expect them to be expected to be enforced - expect your client to be accessible by the whole network.

## Exit Nodes

To add an exit node, create a preauth secret on the `vpn.qo.is` host:

```bash
headscale preauthkeys create --user srv --reusable
```

and configure the host as follows:

```nix
# TODO: This should not be a snipped but a module

{config, ...}: {
  # Use this node as vpn exit node
  services.tailscale = let meta = config.qois.meta; in {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
    authKeyFile = "/secrets/wireguard/tailscale-key"; # The preauth secret. TODO: Should be in sops.
    extraUpFlags = [
      "--login-server=https://vpn.qo.is"
      "--advertise-exit-node"
      (
        with meta.network.virtual.backplane.v4; "--advertise-routes=${id}/${builtins.toString prefixLength}"
      )
      "--advertise-tags=tag:srv"
    ];
  };
}
```

and register it in Headscale with:

```bash
headscale nodes register -u srv -k nodekey:xyzxyzxyzxyzxyzxyzxyzxyz
```

With using the `srv` user, exit nodes and routes get automatically accepted as trusted.

## Clients

### NixOS

Sample config:

```nix
{ config, pkgs, ... }: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
    authKeyFile = "/secrets/wireguard/tailscale-key"; # This is the pre-auth secret. Make sure it's only accessible by root.
    extraUpFlags = [
      "--operator"
      "yourUserNameChangePlease"
      "--accept-routes"
      "--exit-node=100.64.0.5"
      "--login-server=https://vpn.qo.is"
    ];
  };
}
```

### Mobile App

> Android App: Tip 5 times on the tooltip dots to reveal server config option

See [this Headscale documentation for more](https://headscale.net/android-client/#configuring-the-headscale-url) on how to configure the mobile app. Note that on restarts, sometimes you have to reopen/save the config dialog. If the Tailscale login site is shown, just close the browser with the ❌.


## Backup and Restore

### Server

1. `systemctl stop headscale`
2. Replace `/var/lib/headscale`
3. `systemctl start headscale`
4. Monitor logs for errors

Note: `/var/lib/headscale` contains a sqlite database.

### Clients

1. `systemctl stop tailscaled`
2. Replace `/var/lib/tailscale`
3. `systemctl start tailscaled`
4. Monitor logs for errors
