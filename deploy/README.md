# Deployment

Note that you have to be connected to the `vpn.qo.is`
(or execute the deployment from a host that is in the `backplane.net.qo.is` overlay network)
and that you need to have SSH root access to the target machines.

## Deploy system categories

We currently split out nixosConfigurations into these categories:

- `system-ci`: Systems should be updated separately because they might break automated deployment processes.
- `system-vm`: Virtual systems.
- `system-physical`: Physical systems.

You can roll updates with retries by category with:

```bash
auto-deploy system-vm
auto-deploy system-physical
```

## Deploy to selected target hosts

```bash
nix develop

deploy --skip-checks .#cyprianspitz.system-physical
deploy --skip-checks .#lindberg-build.system-vm
```
