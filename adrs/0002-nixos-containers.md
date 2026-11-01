# ADR 0002: NixOS Containers

- Status: Proposed
- Date: 2026-11-01

## Context

Some services need isolation from their host, but not a full VM.
A first attempt, running a service in a systemd-nspawn container, showed what has to be settled
once for all containers:

- state that survives a restart,
- secrets,
- client IPs through both loadbalancers,
- egress isolation,
- duplicated identities and domains,
- monitoring.

## Decision

### Runtime

- Containers are NixOS declarative containers (`containers.<name>`, systemd-nspawn).
- `privateUsers = "pick"` with `--private-users-ownership=map`, `privateNetwork = true`.
- `ephemeral = true`: the root filesystem is discarded on every start.
  `--volatile` and `--read-only` are not used, because NixOS activation needs a writable root.
- Hardening via `extraFlags`, one flag per value, because the start script word-splits them:
  - `--no-new-privileges=yes`
  - `--drop-capability=CAP_NET_RAW,CAP_MKNOD,CAP_SYS_PTRACE,CAP_AUDIT_WRITE`
  - `--system-call-filter=~<group>` for each of `@clock @cpu-emulation @debug @module @obsolete @raw-io @reboot @swap`
- Resource limits (`MemoryHigh`, `MemoryMax`, `CPUQuota`) go on `container@<name>.service`.

### Identity

- A container is described once, in `qois.meta`: its name, its `host` and its IP.
  The name is host-agnostic, e.g. `jellyfin`, not `lindberg-jellyfin`.
- Its configuration lives in `nixos-configurations/<name>/` with `boot.isContainer = true`.
  It is built by the flake checks, is imported by the host's `containers.<name>.config`, and has
  no deploy-rs node of its own.
- Host-level services (backup, mail, telegraf, vector) are disabled in the container via
  `mkDefault` overrides; the host provides them.

### State

- Only explicitly listed paths persist, as idmapped binds
  (`--bind=/var/lib/container-state/<name>/<path>:<path>:idmap`), typically:
  - the application state
  - `/var/lib/acme`
  - `/var/log/journal`
- A fixed `--uuid` keeps the machine id, and therefore the journal directory, stable across boots.
- Backups include `/var/lib/container-state/<name>`, not the container root.
- Persistent binds need a host filesystem with idmapped mount support (e.g. ext4, btrfs).

### Networking

- All containers share the host-agnostic `containers` network (`10.246.0.0/24`).
  Each container has a `/32` from it, routed to its `host`.
- The host-side veth address is the host's backbone IP
  (see [ADR 0001](0001-static-backbone-network.md)).
  Between hosts, the routes are carried by the backbone, so moving a container is a change of
  its `host` in meta (plus moving its state).
- Firewall rules on the container host are derived from meta and implemented as an allowlist:
  - ingress: only `80`/`443` from the loadbalancers' backbone IPs,
  - egress: DNS on the host, and the internet via NAT,
  - everything else is dropped, i.e. all RFC1918, backplane and backbone ranges and the
    host's other ports.

### Ingress

- Both HAProxy loadbalancers forward directly to the container IP, over the backbone or the
  local veth.
  Each uses `send-proxy-v2` and `timeout tunnel` for long-lived connections.
- There is one PROXY hop per request, so nginx in the container trusts exactly the
  loadbalancers' backbone IPs (`qois.nginx.behindLoadbalancer`).
- Applications that classify clients by IP (e.g. "local network") are configured with
  explicit subnets.

### DNS

- The container declares its domains once.
  The loadbalancer domain map and the knot zone records (`nixos-modules/knot`) are derived
  from that declaration.
- An assertion rejects a domain that is declared by more than one container or service.

### Secrets

- sops secrets are decrypted on the host and passed in with
  `--load-credential=<id>:<path>`.
  Their `restartUnits` include `container@<name>.service`.
- Inside the container they are read from `/run/credentials/@system/<id>`.
  Service modules take `*File` options, so they don't depend on the nspawn mechanism.

### Single Sign-On

- Services that support OIDC authenticate against id.qo.is (kanidm).
- The host declares the `qois.kanidm-relying-party.<name>` consumer:
  - `unit = "container@<name>"`
  - its client secret is passed in like any other credential.

### Observability

- The host monitors the container. Telegraf checks the `container@<name>` unit and the
  service over HTTP, and Alertmanager alerts on failures.
- The persisted container journal is shipped to Loki by the host's vector.

### Testing

- Each container has a NixOS VM test that runs it as a container on a host with HAProxy.
  It checks that:
  - the container is `running` and hardened (`NoNewPrivs`),
  - credentials are loaded,
  - the client IP survives the loadbalancer,
  - state survives a container restart.
- These tests need `virtualisation.useBootLoader = true`, because idmapped binds don't work on
  the default 9p/erofs store.

### Module Interface

The conventions above are to be wrapped in one module. Sketch:

```nix
qois.containers.<name> = {
  config = ../<name>;               # NixOS module of the container
  domains = [ "service.qo.is" ];    # loadbalancer + DNS
  statePaths = [ "/var/lib/service" "/var/lib/acme" "/var/log/journal" ];
  credentials.<id> = <path>;        # --load-credential, restarts the container
  resources = { memoryMax = "4G"; cpuQuota = "200%"; };
};
```

Its `host` and IP come from `qois.meta`. The module is active only on the host that runs the
container, and it contributes the routes, domains and DNS records to every other host.

## Consequences

- Containers are cheaper than VMs and can move between physical hosts without changes on the
  loadbalancers.
- The root filesystem is reproducible: config changes always apply, and state is limited to
  declared paths.
- It depends on the static backbone ([ADR 0001](0001-static-backbone-network.md)).
- Moving a container still means moving its state by hand.
- Containers share the host kernel, so their isolation is weaker than a VM's.
