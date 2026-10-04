static_config=$1
config=$2

toml_string() {
  jq --raw-input --slurp 'rtrimstr("\n")' "$1"
}

rm -f "$config"
umask 077
{
  cat "$static_config"
  echo "token = $(toml_string "$CREDENTIALS_DIRECTORY/token")"
  echo "mail_password = $(toml_string "$CREDENTIALS_DIRECTORY/mail-password")"
} >"$config"
chown "root:$(stat -c %g "$(dirname "$config")")" "$config"
chmod 0440 "$config"
