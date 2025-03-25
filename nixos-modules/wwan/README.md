# WWAN Module {#\_wwan_module}

This module configures WWAN adapters that support MBIM

## Current limitations {#\_current_limitations}

- IPv4 tested only
- Currently, it is not simple to get network failures or address
  updates via a hook or so.
  - A systemd timer to update the configuration is executed every 2
    minutes to prevent longer downtimes.
