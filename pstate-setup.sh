#!/bin/sh
# Adapt the setup to the 6.8 kernel with amd_pstate (amd-pstate-epp driver):
#  1. TLP: amd_pstate has only performance/powersave governors and no global boost switch.
#     eco = powersave + EPP "power" + max freq capped at base clock (replaces boost off);
#     performance = performance governor, full range up to max boost.
#  2. Re-run prime-select on-demand: a stale /lib/modprobe.d/blacklist-nvidia.conf
#     keeps the NVIDIA driver from loading.
#  3. Install the updated cpu-menu / cpu-tune / service.
# Run: sudo ./pstate-setup.sh, then reboot.
# Booting the old 5.15 kernel after this: eco mode runs at 1200 MHz (powersave on acpi-cpufreq).
set -e
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }

cpu=/sys/devices/system/cpu/cpu0
[ "$(cat $cpu/cpufreq/scaling_driver)" = amd-pstate-epp ] || { echo "amd_pstate is not active"; exit 1; }
base=$(( $(cat $cpu/acpi_cppc/nominal_freq) * 1000 ))
max=$(cat $cpu/cpufreq/cpuinfo_max_freq)
min=$(cat $cpu/cpufreq/cpuinfo_min_freq)

tlp=/etc/tlp.d/90-power-modes.conf
cp $tlp "$tlp.bak.$(date +%Y%m%d-%H%M%S)"
sed -i '/^CPU_SCALING_GOVERNOR_ON_BAT=/s/=.*/=powersave/' $tlp
sed -i '/^CPU_ENERGY_PERF_POLICY_ON_/d; /^CPU_SCALING_M[AI][XN]_FREQ_ON_/d; /^# amd_pstate:/d' $tlp
sed -i "/^CPU_BOOST_ON_BAT=/a\\
# amd_pstate: EPP hint (powersave governor) and boost via max freq (no boost switch)\\
CPU_ENERGY_PERF_POLICY_ON_AC=performance\\
CPU_ENERGY_PERF_POLICY_ON_BAT=power\\
CPU_SCALING_MIN_FREQ_ON_AC=$min\\
CPU_SCALING_MAX_FREQ_ON_AC=$max\\
CPU_SCALING_MIN_FREQ_ON_BAT=$min\\
CPU_SCALING_MAX_FREQ_ON_BAT=$base" $tlp
grep -E '^CPU_' $tlp

prime-select on-demand
ls /lib/modprobe.d/blacklist-nvidia.conf 2>/dev/null && echo "WARNING: NVIDIA blacklist still present"

./install.sh
echo "Reboot now."
