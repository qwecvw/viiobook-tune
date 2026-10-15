#!/bin/sh
# Let the NVIDIA GPU sleep (RTD3) in prime-select on-demand mode.
#  1. Drop nvidia.NVreg_DynamicPowerManagement=0 from the kernel cmdline (it overrides
#     the 0x02 that prime-select writes to /lib/modprobe.d/nvidia-runtimepm.conf).
#  2. Keep TLP's RUNTIME_PM_ON_AC=on away from the GPU, so its driver controls sleep.
# Run: sudo ./gpu-setup.sh, then reboot.
# Undo: sudo cp /etc/default/grub.bak.<date> /etc/default/grub && sudo update-grub
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }

grub=/etc/default/grub
if grep -q 'nvidia.NVreg_DynamicPowerManagement=0' $grub; then
  cp $grub "$grub.bak.$(date +%Y%m%d-%H%M%S)"
  sed -i 's/ *nvidia\.NVreg_DynamicPowerManagement=0//' $grub
  grep '^GRUB_CMDLINE_LINUX_DEFAULT' $grub
  update-grub
fi

nv=$(lspci -Dn -d 10de: | awk '{print $1}' | sed 's/^0000://' | tr '\n' ' ' | sed 's/ $//')
tlp=/etc/tlp.d/90-power-modes.conf
if [ -n "$nv" ] && ! grep -q '^RUNTIME_PM_DENYLIST=' $tlp; then
  printf '\n# --- NVIDIA: leave runtime PM to the driver so the GPU can sleep (RTD3)\nRUNTIME_PM_DENYLIST="%s"\n' "$nv" >> $tlp
  echo "TLP: RUNTIME_PM_DENYLIST=\"$nv\""
fi
tlp start >/dev/null

"$(dirname "$0")/install.sh"
echo "Reboot now."
