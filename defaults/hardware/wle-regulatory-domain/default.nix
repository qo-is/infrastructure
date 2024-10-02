{
  config,
  lib,
  pkgs,
  ...
}:
{
  boot.kernelPatches = [
    {
      name = "ath10k-override-eeprom-regulatory-domain";
      patch = ./ath10k-override-eeprom-regulatory-domain.patch;
      extraConfig = ''
        EXPERT y
        CFG80211_CERTIFICATION_ONUS y
        ATH_REG_DYNAMIC_USER_REG_HINTS y
        ATH_REG_DYNAMIC_USER_CERT_TESTING y
        ATH_REG_DYNAMIC_USER_CERT_TESTING y
        ATH9K_DFS_CERTIFIED y
        ATH10K_DFS_CERTIFIED y
      '';
    }
  ];
}
