#!/bin/sh
# Move to the HWE 6.8 kernel so amd_pstate can replace acpi-cpufreq
# (any CPU frequency instead of the 3 BIOS P-states, EPP hints).
#  1. Remove the stale hand-installed nvidia 570.169 DKMS module: on a new kernel it could
#     be built after 595 and overwrite it, leaving NVIDIA with a driver/userspace mismatch.
#  2. Install linux-generic-hwe-22.04 (DKMS builds nvidia 595 for it).
#  3. Add amd_pstate=active to the kernel cmdline (ignored by 5.15).
# Run: sudo ./kernel-upgrade.sh, then reboot.
# Fallback: GRUB -> Advanced options -> 5.15.0-186-generic.
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }

if dkms status nvidia/570.169 2>/dev/null | grep -q .; then
  dkms remove nvidia/570.169 --all
  rm -rf /usr/src/nvidia-570.169
fi

apt-get update
apt-get install -y linux-generic-hwe-22.04

new=$(ls /lib/modules | grep '^6\.8' | sort -V | tail -1)
echo "Kernel: $new"
dkms status nvidia | grep "$new" || { echo "WARNING: nvidia DKMS module not built for $new"; }

grub=/etc/default/grub
if ! grep -q 'amd_pstate=' $grub; then
  cp $grub "$grub.bak.$(date +%Y%m%d-%H%M%S)"
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_pstate=active"/' $grub
  sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/  */ /g' $grub
fi
grep '^GRUB_CMDLINE_LINUX_DEFAULT' $grub
update-grub
echo "Reboot now."
