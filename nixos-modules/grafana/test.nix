{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  serverDomain = certs.domain;

  seleniumScript =
    pkgs.writers.writePython3Bin "grafana-selenium-test"
      { libraries = with pkgs.python3Packages; [ selenium ]; }
      ''
        import sys
        from selenium import webdriver
        from selenium.webdriver.common.by import By
        from selenium.webdriver.firefox.options import Options
        from selenium.webdriver.support.ui import WebDriverWait
        from selenium.webdriver.support import expected_conditions as EC

        domain = sys.argv[1]
        base_url = f"https://{domain}"

        options = Options()
        options.add_argument("--headless")
        service = webdriver.FirefoxService(
            executable_path="${lib.getExe pkgs.geckodriver}"  # noqa: E501
        )

        driver = webdriver.Firefox(options=options, service=service)
        driver.implicitly_wait(10)

        # Log in
        driver.get(f"{base_url}/login")
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.NAME, "user"))
        )
        driver.find_element(By.NAME, "user").send_keys("testadmin")
        driver.find_element(By.NAME, "password").send_keys("snakeoilpwd")
        driver.find_element(By.CSS_SELECTOR, "button[type='submit']").click()

        # Navigate to the Overview dashboard
        driver.get(f"{base_url}/d/overview")
        WebDriverWait(driver, 30).until(EC.title_contains("Overview"))

        driver.quit()
      '';
in
{
  args = {
    inherit serverDomain;
  };
  # Note: This extends the default configuration from ${self}/checks/nixos-modules
  nodes = {
    # Using a separated client and server node to verify that the firewall rules work as expected
    client =
      { pkgs, ... }:
      {
        # Resolve serverDomain to the server node and trust the snakeoil CA
        networking.extraHosts = "192.168.1.2 ${serverDomain}";
        security.pki.certificateFiles = [ certs.ca.cert ];

        environment.systemPackages = [
          pkgs.curl
          pkgs.jq
          pkgs.firefox-unwrapped
          pkgs.geckodriver
          seleniumScript
        ];
      };
    server =
      {
        pkgs,
        lib,
        ...
      }:
      {
        qois.grafana = {
          enable = true;
          domain = serverDomain;
        };

        qois.prometheus.enable = true;

        # Use snakeoil certs instead of ACME
        services.nginx.virtualHosts."${serverDomain}" = {
          enableACME = lib.mkForce false;
          sslCertificate = certs.${serverDomain}.cert;
          sslCertificateKey = certs.${serverDomain}.key;
        };
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        qois.postgresql.package = pkgs.postgresql;

        # Dummy sops file so secret paths resolve at eval time
        sops.defaultSopsFile = builtins.toFile "dummy-secrets" (
          builtins.toJSON {
            grafana.admin = {
              user = "unused";
              password = "unused";
            };
          }
        );

        # Override sops-based credentials with env var for testing
        services.grafana.settings.security = lib.mkForce {
          admin_user = "testadmin";
          admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
        };
        systemd.services.grafana.environment.GF_SECURITY_ADMIN_PASSWORD = "snakeoilpwd";
      };
  };
}
