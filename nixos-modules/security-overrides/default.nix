{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) versionAtLeast versionOlder warnIf;
  inherit (pkgs.stdenv.hostPlatform) system;

  # Packages of the nixpkgs commit `rev` (e.g. the backport merge commit).
  # Get `narHash` with: nix flake prefetch github:NixOS/nixpkgs/<rev>
  nixpkgsAt =
    {
      rev,
      narHash,
    }:
    import (fetchTree {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      inherit rev narHash;
    }) { inherit system; };

  # Use `override` until `stable` contains the fix (version `fixedIn`).
  # Fails if `override` does not contain the fix.
  # Warns when stable contains the fix, then remove the override.
  # Set `fixedIn = null` if the fix is a patch without a version change. Then no check occurs.
  securityOverride =
    {
      stable,
      override,
      fixedIn,
      reason,
    }:
    if fixedIn == null then
      override
    else if versionOlder override.version fixedIn then
      throw "Security override for ${override.pname} (${reason}): override has ${override.version}, fix needs ${fixedIn}."
    else
      warnIf (versionAtLeast stable.version fixedIn)
        "Security override for ${stable.pname} (${reason}) is obsolete: stable has ${stable.version}. Remove it from nixos-modules/security-overrides."
        override;
in
{
  services.nginx.package = securityOverride {
    stable = pkgs.nginxStable;
    override =
      (nixpkgsAt {
        rev = "1e6cf0d7cf5f5354d1bfd7105813dddb527851d4"; # nixos-26.05-small, contains 1.30.7
        narHash = "sha256-zAW6zDvAWMptz3WwRl0jX9khtVsgKTDbm7POQqIgYc4=";
      }).nginxStable;
    fixedIn = "1.30.7";
    # https://nginx.org/en/security_advisories.html
    reason = "NGINX2Root: CVE-2026-123007, CVE-2026-123634, CVE-2026-123633, CVE-2026-121810, CVE-2026-113425";
  };

  services.nextcloud.phpPackage = securityOverride {
    stable = pkgs.php84;
    override =
      (nixpkgsAt {
        rev = "69467f449339164b3f036b1dfa27b1b0c5e38925"; # merge of backport NixOS/nixpkgs#590478 to release-26.05
        narHash = "sha256-zmAhBnYUn1isWKdRr5T+qnQNJ4iwRvpMtnsbQfSh3Pg=";
      }).php84;
    fixedIn = "8.4.28";
    # https://www.php.net/ChangeLog-8.php#8.4.28
    reason = "PHP 8.4.28 security release: CVE-2026-129496, CVE-2026-129289, CVE-2026-129292, CVE-2026-129291, CVE-2026-128090, CVE-2026-126714, CVE-2026-115560, CVE-2026-129481, CVE-2026-15353, CVE-2026-129506, CVE-2026-128064, CVE-2026-127960";
  };
}
