# router-wireless-ap

## Overview

2.4 GHz access point via hostapd, bridged into the router LAN.

## Interface

- `qois.router.wireless.enable` (bool) [default.nix:options.qois.router.wireless.enable]
- `qois.router.wireless.wleInterface24Ghz` (nullOr str, default null) [default.nix:options.qois.router.wireless.wleInterface24Ghz]
- `qois.router.wireless.ssid` (str, required) [default.nix:options.qois.router.wireless.ssid]
- `qois.router.wireless.passphrase` (str, required; not read by the config) [default.nix:options.qois.router.wireless.passphrase]
- `qois.router.wireless.regulatoryCountryCode` (str, default `"US"`) [default.nix:options.qois.router.wireless.regulatoryCountryCode]

## Invariants

- hostapd is enabled only when `wleInterface24Ghz` is non-null [default.nix:services.hostapd.enable]
- The radio uses channel 6, 802.11n only (`wifi5` disabled), WPA2-PSK with CCMP, no management frame protection [default.nix:services.hostapd.radios]
- The WPA password is read from `/secrets/wifi_<ssid>` on the host [default.nix:wpaPasswordFile]
- The network is bridged into `lan` (hardcoded, not `internalBridgeInterfaceName`); hostapd starts after `lan-netdev.service` [default.nix:settings.bridge] [default.nix:systemd.services.hostapd.after]

## Side Effects

- Sets `cfg80211 ieee80211_regdom` via `boot.extraModprobeConfig` [default.nix:boot.extraModprobeConfig]
- Enables `services.hostapd` [default.nix:services.hostapd]

## Verification

- Run: `nix flake check`
