# Network

This document provides an overview over the qo.is network structure.

## Physical View

```plantuml
@startuml
skinparam style strictuml
left to right direction

package "plessur.net.qo.is" {

  entity mediaconvchur [
    Media
    Converter
    (Passive)
  ]

  node calanda 
  node fulberg
  
  cloud plessurnet [
    <i>LAN Plessur
  ]
  
  mediaconvchur - "enp4" calanda
  calanda "br0 (enp2, wlp1, wlp5)" --- plessurnet
  calanda "enp4" -- "eno1" fulberg
} 

package "riedbach.net.qo.is" {
  node riedbachrouter

  node lindberg

  riedbachrouter -- "enp5s0" lindberg
}

package "eem.net.qo.is" {
  node eemrouter

  node stompert

  eemrouter -- "enp2s0" stompert
}

cloud internet[
<b>@
]

package "coredump.net.qo.is" {
  node coredumprouter

  node tierberg

  coredumprouter -- "enpXs0" tierberg
}

internet .. mediaconvchur: INIT7 Fiber (1G/1G)
internet .. riedbachrouter: iway Fiber (1G/1G)
internet .. eemrouter: KPN NL Fiber
internet .. coredumprouter: Openfactory DSL
@enduml
```

## DNS

All Services are published under the *qo.is* domain name. Following services are available:

`qo.is` Primery Domain - Redirect to docs.qo.is and some .well-known ressources

{{#include ../backplane-net/README.md}}

## Contacts


### Init7

- [Status Netzwerkdienste](https://www.init7.net/status/)
- [NOC E-Mail](mailto:noc@init7.net)
- +41 44 315 44 00
- Init7 (Schweiz) AG, Technoparkstrasse 5, CH-8406 Winterthur
