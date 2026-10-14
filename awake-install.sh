#!/bin/sh
# The machine never sleeps and its screen never blanks or turns off. Run as root.
# Undo: delete /etc/systemd/logind.conf.d/10-kimera-awake.conf, put /etc/default/grub.before-awake back and run
# update-grub, then  systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
set -e
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\nHandleLidSwitchDocked=ignore\nHandleSuspendKey=ignore\nHandleHibernateKey=ignore\nIdleAction=ignore\n' \
  > /etc/systemd/logind.conf.d/10-kimera-awake.conf
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
# the text screen no longer blanks after a minute
if [ -f /etc/default/grub ]; then
  cp -n /etc/default/grub /etc/default/grub.before-awake
  sed -i 's/ *consoleblank=[0-9]*//' /etc/default/grub
  update-grub >/dev/null 2>&1 || true
fi
echo 0 > /sys/module/kernel/parameters/consoleblank 2>/dev/null || true
systemctl kill -s HUP systemd-logind      # reloads its settings without ending sessions
echo "sleep targets: $(systemctl is-enabled sleep.target 2>&1)   consoleblank now: $(cat /sys/module/kernel/parameters/consoleblank)"
echo "AWAKE-DONE"
