{
  attic-client,
  findutils,
  gnugrep,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "cache";
  meta.description = "Access the infrastructure's attic cache. Mostly used in CI.";
  runtimeInputs = [
    attic-client
    findutils
    gnugrep
  ];
  text = ''
    SERVER="https://attic.qo.is/"
    CACHE_NAME="qois"
    CACHE_REPO="$CACHE_NAME:qois-infrastructure"
    if [ -z "$ATTIC_AUTH_TOKEN" ]; then
      echo "Please set the \$ATTIC_AUTH_TOKEN environment variable to access the cache."
      exit 3
    fi
    attic login "$CACHE_NAME" "$SERVER" "$ATTIC_AUTH_TOKEN"

    case "$1" in
      use)
        attic use "$CACHE_REPO"
      ;;
      watch)
        attic watch-store "$CACHE_REPO"
      ;;
      push)
        RESULT_PATH="./result"
        # Add build dependencies as well
        nix-store -qR --include-outputs "$(nix-store -qd $RESULT_PATH)"   | grep -v '\.drv$' \
          | xargs attic push "$CACHE_REPO" "$RESULT_PATH"
      ;;

    esac
  '';
}
