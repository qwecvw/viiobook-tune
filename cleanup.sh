#!/bin/sh
# One-off cleanup after the move to the 6.8 kernel + NVIDIA 595:
#  1. Purge the leftover NVIDIA 590 packages (595 owns every shared file: checked with dpkg -S).
#  2. Purge old 5.15 kernels except 5.15.0-186 (kept as the GRUB fallback) and the 5.15
#     meta packages, so updates stop installing new 5.15 kernels next to the HWE ones.
#  3. Purge removed-but-not-purged ("rc") kernel/NVIDIA packages, then drop /lib/modules dirs
#     no package owns any more (old DKMS leftovers).
#  4. GRUB menu timeout 10 s -> 3 s.
# Run: sudo ./cleanup.sh
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
keep=5.15.0-186-generic

pkgs=$(dpkg -l | awk '/^ii/ && $2 ~ /-590/ {print $2}')
for v in $(ls /boot | sed -n 's/^vmlinuz-\(5\.15\..*-generic\)$/\1/p'); do
  [ "$v" = $keep ] && continue
  base=${v%-generic}
  pkgs="$pkgs $(dpkg -l "linux-*-$v" "linux-headers-$base" 2>/dev/null | awk '/^ii/ {print $2}')"
done
pkgs="$pkgs $(dpkg -l linux-generic linux-image-generic linux-headers-generic 2>/dev/null | awk '/^ii/ {print $2}')"
# Already removed packages that still hold config/module dirs (dpkg state "rc")
pkgs="$pkgs $(dpkg -l | awk '/^rc/ && $2 ~ /^(linux-.*5\.15\.|nvidia-|libnvidia-)/ && $2 !~ /'$keep'/ {print $2}')"

echo "Purging:" $pkgs
# shellcheck disable=SC2086
apt-get purge -y $pkgs

for d in /lib/modules/*; do
  v=${d##*/}
  [ "$v" = "$(uname -r)" ] || [ "$v" = $keep ] && continue
  if ! dpkg -S "$d" >/dev/null 2>&1; then echo "rm $d"; rm -rf "$d"; fi
done

sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
update-grub
echo "Kernels left:"; ls /lib/modules
