#!/usr/bin/env bash

#### Environment
FLAKE_ROOT="$(git rev-parse --show-toplevel)"
PROMPT_DELAY_SECONDS=3

HOST="${1:-}"
if [ -z "${HOST}" ]; then
  echo "🛑 Error: No host was specified as first parameter (e.g. \"${0} cyprianspitz\")" 1>&2
  exit 1
fi

case "${HOST}" in
cyprianspitz)
  # Reached through calanda, which forwards 8223 to the initrd ssh server.
  SSH_TARGET="root@calanda.plessur-ext.net.qo.is"
  SSH_PORT=8223
  ;;
lindberg)
  SSH_TARGET="root@lindberg.riedbach-ext.net.qo.is"
  SSH_PORT=2222
  ;;
*)
  echo "🛑 Error: Host ${HOST} has no encrypted disks requiring an unlock." 1>&2
  exit 1
  ;;
esac

#### Execution
PASSPHRASE="$(sops decrypt --extract '["system"]["hdd"]' \
  "${FLAKE_ROOT}/private/nixos-configurations/${HOST}/secrets.sops.yaml")"

echo "🔑 Unlocking ${HOST} via ${SSH_TARGET}:${SSH_PORT}..."

# Both initrd variants ask for the passphrase on the ssh tty instead of
# accepting a command, so force a tty and write the passphrase into it once the
# prompt had time to appear. The session is dropped by the host as soon as boot
# continues, hence the ignored exit status.
{
  sleep "${PROMPT_DELAY_SECONDS}"
  printf '%s\n' "${PASSPHRASE}"
} | ssh -o StrictHostKeyChecking=accept-new -tt -p "${SSH_PORT}" "${SSH_TARGET}" || true
