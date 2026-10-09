key_value_fields() {
  awk '{ printf "%s%s=%si", separator, $1, $2; separator = "," }' "$1"
}

escape_tag_value() {
  sed 's/[ ,=\\]/\\&/g'
}

for fs in /sys/fs/btrfs/*/; do
  [ -d "$fs/devinfo" ] || continue

  tags="fsid=$(basename "$fs")"
  label=$(escape_tag_value <"$fs/label")
  [ -n "$label" ] && tags="$tags,label=$label"

  for device in "$fs"devinfo/*/; do
    echo "btrfs_device_errors,$tags,devid=$(basename "$device") $(key_value_fields "$device/error_stats")"
  done

  allocated=0
  for allocation in "$fs"allocation/*/; do
    read -r total_bytes <"$allocation/total_bytes"
    read -r bytes_used <"$allocation/bytes_used"
    read -r disk_total <"$allocation/disk_total"
    read -r disk_used <"$allocation/disk_used"
    echo "btrfs_allocation,$tags,type=$(basename "$allocation") total_bytes=${total_bytes}i,bytes_used=${bytes_used}i,disk_total=${disk_total}i,disk_used=${disk_used}i"
    allocated=$((allocated + disk_total))
  done

  device_size=0
  for size_file in "$fs"devices/*/size; do
    read -r sectors <"$size_file"
    device_size=$((device_size + sectors * 512))
  done
  echo "btrfs_space,$tags device_size=${device_size}i,unallocated=$((device_size - allocated))i"

  echo "btrfs_commits,$tags $(key_value_fields "$fs/commit_stats")"
done
