def test(subtest, webserver):
    webserver.wait_for_unit("nginx")
    webserver.wait_for_open_port(80)

    # Preparations
    webserverRoot = "/var/lib/nginx-docs.example.com/root"
    indexContent = "It works!"
    webserver.succeed(f"mkdir {webserverRoot}")
    webserver.succeed(f"echo '{indexContent}' > {webserverRoot}/index.html")
    webserver.succeed(f"chown -R nginx-docs.example.com\: {webserverRoot}")

    # Helpers
    def curl_variable_test(node, variable, expected, url):
        value = node.succeed(
            f"curl -s --no-location -o /dev/null -w '%{{{variable}}}' '{url}'"
        )
        assert (
            value == expected
        ), f"expected {variable} to be '{expected}' but got '{value}'"

    def expect_http_code(node, code, url):
        curl_variable_test(node, "http_code", code, url)

    def expect_http_location(node, location, url):
        curl_variable_test(node, "redirect_url", location, url)

    def expect_http_content(node, expectedContent, url):
        content = node.succeed(f"curl --no-location --silent '{url}'")
        assert content.strip() == expectedContent.strip(), f"""
                expected content:
                  {expectedContent}
                at {url} but got following content:
                  {content}
            """

    # Tests
    with subtest("website is successfully served on docs.example.com"):
        webserver.succeed("grep docs.example.com /etc/hosts")
        expect_http_code(webserver, "200", "http://docs.example.com/index.html")
        expect_http_content(
            webserver, indexContent, "http://docs.example.com/index.html"
        )

    with subtest("example.com is a redirect to docs.example.com"):
        webserver.succeed("grep -e '[^\.]example.com' /etc/hosts")

        url = "http://example.com/index.html"
        expect_http_code(webserver, "301", url)
        expect_http_location(webserver, "http://docs.example.com/index.html", url)
