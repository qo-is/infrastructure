{ lib }:

with lib;

let
  # Deterministic MAC from VM name: 02:xx:xx:xx:xx:xx (locally-administered)
  macAddress =
    name:
    let
      hash = builtins.hashString "sha256" "microvm-${name}";
      hex = c: builtins.substring c 2 hash;
    in
    "02:${hex 0}:${hex 2}:${hex 4}:${hex 6}:${hex 8}";

  # IPv4 arithmetic helpers
  parseIPv4 = addr: map builtins.fromJSON (splitString "." addr);
  formatIPv4 = octets: concatStringsSep "." (map toString octets);
  addToIPv4 =
    addr: offset:
    let
      octets = parseIPv4 addr;
      total = foldl' (acc: o: acc * 256 + o) 0 octets + offset;
    in
    formatIPv4 [
      (mod (total / 16777216) 256)
      (mod (total / 65536) 256)
      (mod (total / 256) 256)
      (mod total 256)
    ];
in
{
  inherit
    macAddress
    parseIPv4
    formatIPv4
    addToIPv4
    ;
}
