{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    attrValues
    concatMapAttrs
    flatten
    getAttr
    head
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    pipe
    tail
    types
    ;

  cfg = config.qois.static-page;
in
{
  imports = [ ./default-pages.nix ];

  options.qois.static-page =
    let
      pageType =
        { name, ... }:
        {
          options = {
            domain = mkOption {
              type = types.str;
              default = name;
              description = ''
                Primary domain, under which the site is served.
                Only ASCII Domains are supported at this time.
                Note that changing this changes the vhost root /var/lib/nginx-$domain/.local/state/nix/profiles/webroot and the ssh user to "nginx-$domain".
              '';
            };

            domainAliases = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Domain aliases which are forwarded to the primary domain";
            };

            authorizedKeys = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "SSH keys for deployment";
            };
          };
        }

      ;
    in
    {
      enable = mkEnableOption "Enable static-page hosting";
      pages = mkOption {
        type = types.attrsOf (types.submodule (pageType));
      };
    };

  config = mkIf cfg.enable (
    let
      pageConfigs = concatMapAttrs (
        _name: page:
        let
          user = "${config.services.nginx.user}-${page.domain}";
          home = "/var/lib/${user}";
        in
        {
          "${page.domain}" = page // {
            inherit home;
            inherit user;
            root = "${home}/.local/state/nix/profiles/webroot";
          };
        }
      ) cfg.pages;

    in
    {
      networking.hosts."127.0.0.1" = pipe pageConfigs [
        attrValues
        (map (page: [ page.domain ] ++ page.domainAliases))
        flatten
      ];

      users = {
        groups = concatMapAttrs (
          _name:
          { user, ... }:
          {
            "${user}" = { };
          }
        ) pageConfigs;
        users = {
          ${config.services.nginx.user}.extraGroups = mapAttrsToList (_domain: getAttr "user") pageConfigs;
        }
        // (concatMapAttrs (
          _name:
          {
            user,
            home,
            authorizedKeys,
            ...
          }:
          {
            ${user} = {
              inherit home;
              isSystemUser = true;
              useDefaultShell = true;
              homeMode = "750";
              createHome = true;
              group = user;
              openssh.authorizedKeys.keys = authorizedKeys;
            };
          }
        ) pageConfigs);
      };

      qois.telegraf.serviceInputs.x509_cert = [
        {
          sources = pipe cfg.pages [
            attrValues
            (map (page: [ "https://${page.domain}:443" ] ++ map (d: "https://${d}:443") page.domainAliases))
            flatten
          ];
        }
      ];

      services.nginx = {
        enable = true;
        virtualHosts =
          let
            defaultVhostConfig = {
              enableACME = true;
              forceSSL = true;
            };
            mkVhost =
              { root, ... }:
              defaultVhostConfig
              // {
                inherit root;
              };
            mkAliasVhost =
              { domainAliases, domain, ... }:
              if (domainAliases == [ ]) then
                { }
              else
                {
                  "${head domainAliases}" = defaultVhostConfig // {
                    serverAliases = tail domainAliases;
                    globalRedirect = domain;
                  };
                };
            aliasVhosts = concatMapAttrs (_name: mkAliasVhost) pageConfigs;

          in
          aliasVhosts // (mapAttrs (_name: mkVhost) pageConfigs);
      };
    }
  );
}
