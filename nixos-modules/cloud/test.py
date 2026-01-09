def test(subtest, webserver):
    webserver.wait_for_unit("multi-user.target")
    webserver.wait_for_unit("nginx")
    webserver.wait_for_open_port(80)

    # Helpers
    def curl_variable_test(node, variable, expected, url):
        value = node.succeed(
            f"curl -s --no-location -o /dev/null -w '%{{{variable}}}' '{url}'"
        )
        assert value == expected, (
            f"expected {variable} to be '{expected}' but got '{value}'"
        )

    def expect_http_code(node, code, url):
        curl_variable_test(node, "http_code", code, url)

    def expect_http_content_contains(node, expectedContentSnippet, url):
        content = node.succeed(f"curl --no-location --silent '{url}'")
        assert expectedContentSnippet in content, f"""
                expected in content:
                  {expectedContentSnippet}
                at {url} but got following content:
                  {content}
            """

    # Tests
    with subtest("website is successfully served on cloud.example.com"):
        webserver.succeed("grep cloud.example.com /etc/hosts")
        expect_http_code(webserver, "200", "http://cloud.example.com")
        expect_http_content_contains(
            webserver, "Log in to cloud.qoo.is", "http://docs.example.com"
        )
