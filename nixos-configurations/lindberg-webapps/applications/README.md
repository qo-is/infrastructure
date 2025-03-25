# Web Apps

## Setting up new static sites

Generate ssh key for deployment:

```bash
export SSH_KEYFILE=$(mktemp --dry-run -- /dev/shm/key-XXXXXXXXX)
mkfifo -m 600 $SSH_KEYFILE
ssh-keygen -q -t ed25519 -C "ci@git.qo.is" -N "" -f $SSH_KEYFILE <<< "y\ny\n" &
wl-copy --trim-newline --foreground --paste-once < $SSH_KEYFILE
# Paste private key in CI secret "SSH_DEPLOY_KEY" now

# Configure public key:
wl-copy --trim-newline < ${SSH_KEYFILE}.pub
```
