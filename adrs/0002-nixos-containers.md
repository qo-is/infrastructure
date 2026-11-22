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

- A container is described once, in `qois.meta.network.virtual.containers.hosts.<name>`, with
  its IP (`v4.ip`) and its `host`.
  The container network has no WireGuard keys, so `publicKey` becomes optional.
  The name is host-agnostic, e.g. `jellyfin`, not `lindberg-jellyfin`.
- It has a `hosts.json` entry without `sshKey`, so it is not a deploy or SSH target.
- Its configuration lives in `nixos-configurations/<name>/` with `boot.isContainer = true`.
  It is built by the flake checks, is imported by the host's `containers.<name>.config`, and has
  no deploy-rs node of its own.
- Host-level services (backup, mail, telegraf, vector) are enabled with `mkDefault`, and the
  container sets them to `false`; the host provides them.
- A container host must be a member of the atlas network ([ADR 0001](0001-atlas-network.md)).

### State

- Only explicitly listed paths persist, as idmapped binds
  (`--bind=/var/lib/container-state/<name>/<path>:<path>:idmap`):
  - the application state,
  - always `/var/lib/acme` and `/var/log/journal`.
- The journal needs a bind because nspawn ignores `--link-journal` for ephemeral containers.
  A fixed `--uuid` keeps the machine id, and therefore the journal directory, stable across boots.
- Host data that is not container state (e.g. a media library) is bound in via `dataPaths`.
  This pins the container to its host.
- The host only creates `/var/lib/container-state/<name>`.
  Ownership inside it comes from the container's tmpfiles rules or `StateDirectory`.
- Backups copy `/var/lib/container-state/<name>` while the container runs, like any other
  service's state, and not the container root.
  A container on `cyprianspitz` needs a backup target other than `cyprianspitz`.
- Persistent binds need a host filesystem with idmapped mount support (e.g. ext4, btrfs).

### Networking

- All containers share the host-agnostic `containers` network (`10.246.0.0/24`).
  It is separate from atlas: containers are not atlas peers.
- Every container host uses the same gateway address `10.246.0.1` on its `ve-*` side.
  Each container has a `/32` with its default route via `10.246.0.1`, so its configuration does
  not depend on its host.
- The host routes each local container's `/32` to its veth.
  Between hosts, atlas carries the `/32`s.
- DNS: `useHostResolvConf = false`, nameserver `10.246.0.1`.
  The host resolver answers on `ve-+` only.
- Egress is off by default and opened per container:
  - `internet = true` enables NAT to the internet.
    It is required when `domains` is set, because ACME uses HTTP-01.
  - `egress.containers = [ <name> ]` allows connections to other containers.
    The rule is derived from meta on whichever host the target runs.
  - `egress.hosts = [ "id.qo.is" ]` allows domains served by the loadbalancers.
    The host resolver answers them with the loadbalancers' atlas IPs, which are reached on
    `443`, so no hairpin NAT is needed.
- Firewall rules on the container host are an allowlist, matching `ve-+` or the container IP:
  - established and related connections,
  - ingress: only `80`/`443` from the loadbalancers' atlas IPs,
  - egress: DNS on the host plus the options above,
  - everything else is dropped, i.e. all RFC1918, backplane and atlas ranges and the host's
    other ports.

### Moving a Container

1. Stop it.
1. Sync `/var/lib/container-state/<name>` to the new host.
1. Move its secrets to the new host's sops file.
1. Change its `host` in meta.
1. Deploy all atlas peers.

### Ingress

- Both HAProxy loadbalancers forward directly to the container IP, with their atlas IP as
  source, also for local containers.
  The container therefore sees the same proxy IPs wherever it runs.
- Each uses `send-proxy-v2` and `timeout tunnel` for long-lived connections.
- There is one PROXY hop per request, so nginx in the container trusts exactly the
  loadbalancers' atlas IPs, via a new `qois.nginx.trustedProxies` option.
- Applications that classify clients by IP (e.g. "local network") are configured with
  explicit subnets.

### DNS

- The container declares its domains once.
  They feed `qois.loadbalancer.domains`, and the knot zone records (`nixos-modules/knot`) are
  derived from those.
- The loadbalancer's built-in domains move from the option default into `config`, so container
  domains add to them instead of replacing them.
- An assertion rejects a domain that is declared by more than one container or service.

### Secrets

- Container secrets live in the host's sops file.
  They are decrypted on the host and passed in with `--load-credential=<id>:<path>`.
  Their `restartUnits` include `container@<name>.service`.
- Inside the container, root services read them from `/run/credentials/@system/<id>`, and
  unprivileged services import them with `ImportCredential=<id>`.
  Service modules take `*File` options, so they don't depend on the nspawn mechanism.

### Single Sign-On

- Services that support OIDC authenticate against id.qo.is (kanidm).
- The host declares the `qois.kanidm-relying-party.<name>` consumer with
  `unit = "container@<name>"`.
  Its `user` and `group` own the host's copy of the client secret.
  They are `root`, because only nspawn reads that copy, to pass it in like any other credential.
- The container lists `id.qo.is` in `egress.hosts`.

### Observability

- The host monitors the container. Telegraf checks the `container@<name>` unit
  (`systemd_units`) and the service over HTTPS through the local HAProxy, because nginx in the
  container only accepts PROXY connections.
  Alertmanager alerts on failures.
- The host's vector ships each container's persisted journal directory to Loki.

### Testing

- Each container has a NixOS VM test that runs it as a container on a host with HAProxy.
  It checks that:
  - the container is `running` and hardened (`NoNewPrivs`),
  - credentials are loaded,
  - the client IP survives the loadbalancer,
  - state survives a container restart,
  - without `internet`, the container reaches neither the internet nor the backplane,
  - `egress.containers` allows exactly the listed containers.
- These tests need `virtualisation.useBootLoader = true`, because idmapped binds don't work on
  the default 9p/erofs store.

### Module Interface

The conventions above are to be wrapped in one module. Sketch:

```nix
qois.containers.<name> = {
  config = ../<name>;               # NixOS module of the container
  domains = [ "service.qo.is" ];    # loadbalancer + DNS
  statePaths = [ "/var/lib/service" ];  # plus /var/lib/acme and /var/log/journal
  dataPaths = [ "/srv/media" ];     # host data, pins the container to its host
  internet = true;                  # required with domains
  egress.containers = [ "other" ];
  egress.hosts = [ "id.qo.is" ];
  credentials.<id> = <path>;        # --load-credential, restarts the container
  resources = { memoryMax = "4G"; cpuQuota = "200%"; };
};
```

The module is imported by every host. Its `host` and IP come from `qois.meta`.
The container's `config` is evaluated only on its host, while every other host gets the routes,
domains, DNS records and firewall rules derived from it.

## Consequences

- Containers are cheaper than VMs and can move between physical hosts without changes to the
  HAProxy configuration.
- The root filesystem is reproducible: config changes always apply, and state is limited to
  declared paths.
- It depends on the atlas network ([ADR 0001](0001-atlas-network.md)).
- Moving a container still means moving its state by hand.
- Containers share the host kernel, so their isolation is weaker than a VM's.
- Follow-ups:
  - Once the hosts run systemd ≥ 261 (NixOS 26.11), forward the journal with
    `--forward-journal=<host dir>` (written by the host's `systemd-journal-remote`) and drop the
    journal bind and the fixed `--uuid`.
  - Service-specific items from the first attempt (e.g. testing authenticated API calls) are
    handled in that service's module.
