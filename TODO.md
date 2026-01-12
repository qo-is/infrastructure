# TODO

## Architecture

### Hypervisor

A hypervisor runs services and manages the networking.

### Services

For services, we want those main configurations:

- **service dependencies**
  This allows testing or deployment in order. Should be a DAG.

- **persistant storage**

- **backups**

- **monitoring**

- **network mesh**

  - external port forwarding

- **secret handling**

- **tests**
  Should run dependent services configuration on nodes

- **service configuration**
  Essentially a nixos configuration.

  - Uses secrets, network, pesistent storage config

#### Output:

- Tests of mvms

- Microvm services with:

  - service configuration
  - neccessary secrets
  - microvm config
  -

- Special microvm services for:

  - monitoring
  - backup storage
  - haproxy

- Hypervisor configuration

  - Network configuration for guests
  - port forwarding resp. haproxy configuration
  - DNS
  - storage pool configuration.

### Deployment

Order:

1. Network Devices
1. Hypervisors
1. Microvms
1. Late Upgrade Microvms (e.g. for CI)

### Network

- Hypervisors should have encrypted backplane connection (wireguard)
- Traffic between microservices on different HVs should go via the backplane
- Hosts on the same service shouldn't encrypt the traffic on a network layer among each other at this time (transport level encryption is encouraged nevertheless.)
- Connections should be done based on DNS names so that load-balancing or hot/cold failovers are possible.
