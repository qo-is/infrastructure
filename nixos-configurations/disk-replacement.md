# RAID Disk Replacement Guide - lindberg server

## Environment Setup

```bash
export FAILED_DISK=/dev/disk/by-id/nvme-SAMSUNG_MZVL22T0HBLB-00B00_S677NE0NC01017_1
export FAILED_PARTITION=${FAILED_DISK}-part2
export REPLACEMENT_DISK=/dev/disk/by-id/usb-Realtek_USB_3.2_Device_012345679175-0:0
export RAID_DEVICE=/dev/md/raid_system
```

## Step 1: Remove Failed Disk from RAID

```bash
mdadm $RAID_DEVICE --remove $FAILED_PARTITION
```

## Step 2: Prepare Replacement Disk with Disko

```bash
# Create modified disko config for single disk formatting
nix eval --raw --impure --expr "
let
  flake = builtins.getFlake (toString ./.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  diskoConfig = import ./nixos-configurations/lindberg/disko-config.nix { inherit pkgs; };
  # Extract just the system-1 disk definition with modified device path
  singleDisk = {
    disko.devices = {
      disk = {
        system-1 = diskoConfig.disko.devices.disk.system-1 // {
          device = \"$REPLACEMENT_DISK\";
        };
      };
      # Explicitly empty to prevent RAID/LVM operations
      mdadm = {};
      lvm_vg = {};
    };
  };
in
  builtins.toJSON singleDisk
" > /tmp/disko-replacement.json

# Convert JSON back to nix for disko
cat > /tmp/disko-replacement.nix << 'EOF'
 builtins.fromJSON (builtins.readFile /tmp/disko-replacement.json)
EOF

# Generate partitioning script
disko --dry-run  --mode format /tmp/disko-replacement.nix > /tmp/format-disk.sh


```

- Manually execute partitioning commands as output by disko in `/tmp/format-disk.sh`

## Step 3: Add Replacement Disk to RAID

```bash
# Add to RAID
mdadm $RAID_DEVICE --add ${REPLACEMENT_DISK}-part2

# Monitor rebuild
watch -n 1 cat /proc/mdstat

# Wait for completion
while mdadm --detail $RAID_DEVICE | grep -q "State.*degraded"; do
    sleep 30
done
```

## Step 4: Setup Boot Partition

```bash
mkdir -p /mnt/boot-replace
mount ${REPLACEMENT_DISK}-part1 /mnt/boot-replace
rsync -av /boot-secondary/ /mnt/boot-replace/
umount /mnt/boot-replace
```

## Step 5: Verify and Save Configuration

```bash
mdadm --detail $RAID_DEVICE
mdadm --detail --scan
# Update boot.swraid.mdadmConf if changes from this command
```

## Step 6: Update Boot Configuration (Pre-replacement)

- Uncomment faulty old disk from disko and grub configuration
- Deploy system config

## Step 7: Physical Disk Replacement

```bash
# After rebuild completes (verify with: mdadm --detail $RAID_DEVICE)
shutdown -h now
```

**Physical steps:**

1. Remove failed Samsung NVMe
1. Install replacement SSD in NVMe slot
1. Boot system

**Post-boot:**

```bash
mdadm --detail /dev/md/raid_system
cat /proc/mdstat
```

## Step 8: Update NixOS Configuration (Post-replacement)

```bash
# Get new disk ID
ls -la /dev/disk/by-id/ | grep nvme

```

- Update disko-config.nix and grub config with the new disk config
- Deploy system

## Troubleshooting

```bash
# If rebuild doesn't start
mdadm --manage $RAID_DEVICE --add-spare ${REPLACEMENT_DISK}-part2
```
