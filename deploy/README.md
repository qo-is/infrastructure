# Deployment

Note that you have to be connected to the `vpn.qo.is`
(or execute the deployment from a host that is in the `backplane.net.qo.is` overlay network)
and that you need to have SSH root access to the target machines.



#### Deploy to all hosts

```bash
nix run .#deploy-qois
```


#### Deploy to selected target hosts

```bash
nix run .#deploy-qois .#<hostname> .#<hostname2>

# e.g.
nix run .#deploy-qois .#fulberg
```

#### Deploy with extended timeouts (sometimes required for slow APU devices)

```bash
nix run .#deploy-qois  .#calanda -- --confirm-timeout 600 --activation-timeout 600
```
