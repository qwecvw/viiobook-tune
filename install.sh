#!/bin/sh
# Install cpu-menu + cpu-tune, update power-mode, user-profile hooks, bind Super+Insert (XFCE).
# Run: sudo ./install.sh
set -e
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
user=${SUDO_USER:?run via sudo from your user}

install -o root -g root -m 755 cpu-tune cpu-menu cpu-menu-gtk cpu-fan-guard nv-oc kbd-idle hw-lab power-mode /usr/local/bin/
install -o root -g root -m 755 cpu-menu-sleep /lib/systemd/system-sleep/cpu-menu

# User profile: re-apply at boot (after TLP) and after TLP's charger plug/unplug handling
install -o root -g root -m 644 cpu-menu-user.service cpu-fan-guard.service hw-lab.service /etc/systemd/system/
install -o root -g root -m 644 99-cpu-menu.rules /etc/udev/rules.d/
systemctl daemon-reload
systemctl disable cpu-menu-user.service 2>/dev/null || true
systemctl enable cpu-menu-user.service
systemctl enable cpu-fan-guard.service
systemctl restart cpu-fan-guard.service
udevadm control --reload

tmp=$(mktemp)
sed "s/^yura /$user /" 91-cpu-tune.sudoers > "$tmp"
visudo -cf "$tmp"
install -o root -g root -m 440 "$tmp" /etc/sudoers.d/cpu-tune
rm -f "$tmp"

sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$user")/bus" \
  xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>Insert' \
  -n -t string -s /usr/local/bin/cpu-menu
# Keyboard backlight auto-off: user session autostart, started right away too
home=$(getent passwd "$user" | cut -d: -f6)
sudo -u "$user" install -D -m 644 kbd-idle.desktop "$home/.config/autostart/kbd-idle.desktop"
pkill -u "$user" -f /usr/local/bin/kbd-idle || true
sudo -u "$user" DISPLAY=:0 XAUTHORITY="$home/.Xauthority" setsid /usr/local/bin/kbd-idle 300 >/dev/null 2>&1 &

echo "Done. Press Super+Insert."
