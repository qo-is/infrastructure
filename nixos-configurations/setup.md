# Setup of new hosts

## Prepare Remote Machine

1. Boot nixos installer image
1. Set a root password: `sudo passwd root`
1. Get host ip to connect to ssh with `ip a`

## Verify configuration

1. Verify the network device name in the configuration (e.g. `enp2s0`)

## Installation

````bash
nix develop

# Set according to what we want
REMOTE_IP=<ip>
REMOTE_HOSTNAME=<hostname>

# Verify SSH works, accept newly generated host keys and create directory for system secrets
ssh root@$REMOTE_IP mkdir -p /run/secrets/system/

# Configure Secrets management
HOSTS_FILE="defaults/meta/hosts.json"
REMOTE_SSHKEY="`ssh-keyscan -q -t ed25519 $REMOTE_IP | cut --delimiter ' ' --fields 2-`"
git show ":$HOSTS_FILE" | jq ".${REMOTE_HOSTNAME}.sshKey=\"${REMOTE_SSHKEY}\"" > $HOSTS_FILE
sops-rekey

# Check that:
# - you updated the age key
# - default interface name is correctly configured
# - you are 100% on the right REMOTE_IP (host will be wiped by disko)
# - if you use LUKS secrets, you created a secret "system.hdd" with the disk password:
#   `sops set private/nixos-configurations/$REMOTE_HOSTNAME/secrets.sops.yaml '["system"]["test"]' "\"`pwgen -1 --ambiguous 20 1`\""
# - if you use initrd ssh server (for remote luks unlock), create a "system.initrd-ssh-private" ssh key ();
#   ```bash
#   export SSH_KEYFILE=/tmp/${REMOTE_HOSTNAME}-initrd-ssh-key
#   mkfifo -m 600 $SSH_KEYFILE
#   ssh-keygen -q -t ed25519 -C "boot@${REMOTE_HOSTNAME}" -N "" -f $SSH_KEYFILE <<< "y\ny\n" &
#   sops set private/nixos-configurations/$REMOTE_HOSTNAME/secrets.sops.yaml '["system"]["initrd-ssh-key"]' "\"`cat $SSH_KEYFILE`\""
#   rm $SSH_KEYFILE
#   ```

# Install OS. ⚠️ This clears all local hdds with disko!
nixos-anywhere --copy-host-keys --flake ".#$REMOTE_HOSTNAME" root@$REMOTE_IP
# To use a jumphost, use `--ssh-option "ProxyJump=user@jumphost"`


# TODO:
## qois-setup-host $REMOTE_HOSTNAME $REMOTE_IP --[no]-luks [--generate-system-secrets] [--proxy user@jumphost]
## read: Did you update the AGE keys to the setup tools setup keys? [Enter]
## read: Did you check the interfaces names to be correct? [Enter]
## read: Are you 100% sure the command promt is corect? [Enter]

# With LUKS key:
sops exec-file --no-fifo --filename secret.key private/nixos-configurations/$REMOTE_HOSTNAME/secrets.sops.yaml "
  nixos-anywhere --copy-host-keys --flake .#$REMOTE_HOSTNAME root@$REMOTE_IP \
    --disk-encryption-keys /run/secrets/system/hdd.key <(yq --raw-output '.system.hdd' {}) \
    --disk-encryption-keys /run/secrets/system/initrd-ssh-key <(yq --raw-output '.system.\"initrd-ssh-key\"' {})
"
````

## Post-Setup

- Add backplane-vpn pubkey to `network-virtual.nix` configuration with
  ```bash
  wg pubkey < /secrets/wireguard/private/backplane
  ```
