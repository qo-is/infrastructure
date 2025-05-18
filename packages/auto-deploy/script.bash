#!/usr/bin/env bash

#### Environment
FLAKE_ROOT="$(git rev-parse --show-toplevel)"

export PROFILE="${1:-}"
if [ -z "${PROFILE}" ]; then
  echo "🛑 Error: No deployment profile was specified as first parameter (e.g. \"${0} system-vm\")" 1>&2
  exit 1
fi

if [ -z "${SSH_DEPLOY_KEY:-}" ]; then
  echo "ℹ️ Info: SSH_DEPLOY_KEY env variable was not set, ignoring."
  SSH_KEY_FILE_ARG=""
else
  TEMP_KEY_FILE=$(mktemp /dev/shm/ssh_deploy_key.XXXXXXXX)
  touch "${TEMP_KEY_FILE}" && chmod 600 "${TEMP_KEY_FILE}"
  printf "%s\n" "${SSH_DEPLOY_KEY}" >"${TEMP_KEY_FILE}"
  SSH_KEY_FILE_ARG="-i ${TEMP_KEY_FILE}"

  # Set up a trap to remove the temporary key file on script exit
  trap 'rm -f "${TEMP_KEY_FILE}"' EXIT
  trap 'rm -f "${TEMP_KEY_FILE}"' SIGINT
  trap 'rm -f "${TEMP_KEY_FILE}"' SIGTERM
  trap 'rm -f "${TEMP_KEY_FILE}"' SIGQUIT
fi

HOSTS=$(nix eval --raw "${FLAKE_ROOT}"#deploy.nodes --apply "
   nodes: let
     inherit (builtins) attrNames filter concatStringsSep;
     names = attrNames nodes;
     profile = \"${PROFILE}\";
     filteredNames = filter (name: nodes.\${name}.profiles ? \${profile}) names;
   in concatStringsSep \"\\n\" filteredNames
")
if [ -z "$HOSTS" ]; then
  echo "🛑 Error: No deployments matching the profile ${PROFILE} were found." 1>&2
  exit 1
fi

KNOWN_HOSTS_FILE=$(nix build --no-link --print-out-paths .#nixosConfigurations.lindberg.config.environment.etc."ssh/ssh_known_hosts".source)

#### Helpers
retry() {
  local -r -i max_attempts="$1"
  shift
  local -i attempt_num=1
  until "$@"; do
    if ((attempt_num == max_attempts)); then
      echo "🛑 Error: Attempt $attempt_num failed and there are no more attempts left!" 1>&2
      return 1
    else
      echo "⚠️ Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
      sleep $((attempt_num++))
    fi
  done
}

#### Execution
for HOST in $HOSTS; do
  retry 3 deploy \
    --skip-checks \
    --ssh-opts "-o UserKnownHostsFile=${KNOWN_HOSTS_FILE} ${SSH_KEY_FILE_ARG:-}" \
    --targets "${FLAKE_ROOT}#\"${HOST}\".\"${PROFILE}\""
done
