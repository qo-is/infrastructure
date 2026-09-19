{ lib, qoisMeta, ... }:
let
  inherit (lib)
    attrNames
    elemAt
    imap0
    length
    mergeAttrsList
    mod
    pipe
    ;

  physicalColors = [
    "#e05f65"
    "#f9a872"
    "#5fe1ff"
    "#f5a6b8"
    "#78dba9"
  ];
  virtualColors = [
    "#f1cf8a"
    "#70a5eb"
    "#9dd68d"
    "#c68aee"
    "#9378de"
  ];

  # riedbach-ext is assigned dynamically by the ISP and therefore defines no network
  # id, which makes accessing it throw instead of returning a value.
  tryNetworkId =
    netConfig:
    let
      evaluated = builtins.tryEval netConfig.v4.id;
    in
    if evaluated.success then evaluated.value else null;

  mkCidrV4 =
    netConfig:
    let
      networkId = tryNetworkId netConfig;
    in
    if networkId == null then null else "${networkId}/${toString netConfig.v4.prefixLength}";

  # Physical segments are drawn solid, virtual ones dashed, so that the overlay meshes
  # are distinguishable from the wires they run over.
  mkNetworks =
    {
      pattern,
      colors,
      nameSuffix,
    }:
    networks:
    pipe (attrNames networks) [
      (imap0 (
        index: netName: {
          ${netName} = {
            name = "${networks.${netName}.domain}${nameSuffix}";
            cidrv4 = mkCidrV4 networks.${netName};
            style = {
              inherit pattern;
              primaryColor = elemAt colors (mod index (length colors));
              secondaryColor = null;
            };
          };
        }
      ))
      mergeAttrsList
    ];
in
{
  networks =
    mkNetworks {
      pattern = "solid";
      colors = physicalColors;
      nameSuffix = "";
    } qoisMeta.network.physical
    // mkNetworks {
      pattern = "dashed";
      colors = virtualColors;
      nameSuffix = " (virtual)";
    } qoisMeta.network.virtual;
}
