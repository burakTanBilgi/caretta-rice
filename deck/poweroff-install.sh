#!/bin/sh
# Lets one user power the machine off or start it again without sudo, and nothing else. Run as root:  sh poweroff-install.sh USER
# The rule holds for that user wherever they are logged in, over ssh too, and also while others are logged in.
set -e
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
U=${1:?usage: sh poweroff-install.sh USER}
id "$U" >/dev/null
install -m 755 "$(dirname "$0")/kimera-poweroff" /usr/local/bin/kimera-poweroff
command -v pkaction >/dev/null 2>&1 || echo "note: polkit is not installed (apt install polkitd); the rule does nothing until it is"
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-kimera-poweroff.rules <<R
polkit.addRule(function(action, subject) {
  if (subject.user == "$U" &&
      (action.id == "org.freedesktop.login1.power-off" ||
       action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
       action.id == "org.freedesktop.login1.reboot" ||
       action.id == "org.freedesktop.login1.reboot-multiple-sessions")) {
    return polkit.Result.YES;
  }
});
R
echo "POWEROFF-DONE for $U"
