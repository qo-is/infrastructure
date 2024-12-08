{
  ...
}:

{
  config.services.nginx = {
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedBrotliSettings = true;
    logError = "stderr warn";
    proxyResolveWhileRunning = true;
  };
}
