# VPN

We run a [Tailscale](https://tailscale.com) compatible VPN service on [vpn.qo.is](https://vpn.qo.is).

## User and Client Management

To register a new client on the `vpn.qo.is` host:, generate a pre-auth key and insert it in the client:

```bash
headscale users create marlene.mayer
headscale preauthkeys create --user marlene.mayer
```

> ⚠️ For now, the username must be added to `qois.vpn-server.wheelUsers`.
> In the future, the VPN ACL might get more granular to allow for non-wheel users.

Alternatively to using a pre-auth key, the register command shown when configuring the VPN client may be used.

## ACL

At this time, there are a few ACL rules to isolate a users host but do not expect them to be expected to be enforced - expect your client to be accessible by the whole network.

## Exit Nodes

These nodes allow access to the internet for clients connected to the VPN:

- `100.64.0.5`: lindberg (riedbach-net)
- `100.64.0.6`: cyprianspitz (plessur-net)

> ⚠️ Currently, name resolution for these do not work reliably on first starts, hence the IP must be used. This hould be fixed in the future.

### Add exit nodes:

1. Create a preauth secret on the `vpn.qo.is` host:
   ```bash
    headscale preauthkeys create --user srv --reusable
   ```
1. Configure the new exit-node host with the `qois.vpn-exit-node` module.

When using the `srv` user, exit nodes and routes are automatically accepted as trusted.

## Clients

To use the service, you can use a normal Tailscale client with following additional configuration:

| Option | Recommended value | Description |
|--------|-------------------|-------------|
| `accept-routes` | enabled (flag) | Accept direct routes to internal services |
| `exit-node` | `100.64.0.5` (lindberg) or `100.64.0.6` (cypriaspitz) | Use host as [exit node](#exit-nodes) |
| `login-server` | `https://vpn.qo.is` | Use our own VPN service. |

> ⚠️ Currently, if the client is in an IPv6 network, the transport is broken.
> Disable IPv6 connectivity to use the VPN.
> See [#4](https://git.qo.is/qo.is/infrastructure/issues/4) for details.

### NixOS

Sample config with automatic connectivity to VPN on boot:

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

### Android

See [this Headscale documentation for more](https://headscale.net/stable/usage/connect/android/) on how to configure the mobile app.

> ⚠️ Note that on restarts, sometimes you have to reopen/save the config dialog.
> If the Tailscale login site is shown, just close the browser with the ❌.

## Backup and Restore

### Server

1. `systemctl stop headscale`
1. Replace `/var/lib/headscale`
1. `systemctl start headscale`
1. Monitor logs for errors

Note: `/var/lib/headscale` contains a sqlite database.

### Clients

1. `systemctl stop tailscaled`
1. Replace `/var/lib/tailscale`
1. `systemctl start tailscaled`
1. Monitor logs for errors
