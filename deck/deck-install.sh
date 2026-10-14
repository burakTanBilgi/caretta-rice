#!/bin/sh
# Runs once on Caretta as root, from the folder holding the deck's files.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
U=${SUDO_USER:?run it with sudo from your own user, not as root directly}; here=$(dirname "$0")
log=$(mktemp)
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
  python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-pango-1.0 foot foot-terminfo fontconfig brightnessctl greetd swaylock > "$log" 2>&1 \
  || { tail -5 "$log"; rm -f "$log"; echo "the packages did not install; nothing else was changed"; exit 1; }
rm -f "$log"
# Debian's package may switch greetd on by itself; it stays off until the login screen has been drawn below
[ -f /etc/greetd/config.toml.debian ] || systemctl disable greetd >/dev/null 2>&1 || true
install -d /usr/local/share/fonts/kimera /usr/local/share/kimera /etc/kimera
install -m 644 "$here"/fonts/*.ttf "$here"/fonts/OFL-*.txt /usr/local/share/fonts/kimera/
fc-cache -f /usr/local/share/fonts/kimera
install -m 644 "$here"/caretta-deck.png "$here"/caretta-rest.png "$here"/caretta-login-cells.png "$here"/caretta-login-turtle.png /usr/local/share/kimera/
install -m 755 "$here/caretta-deck-panel" /usr/local/bin/caretta-deck-panel
layout=$(. /etc/default/keyboard 2>/dev/null; echo "${XKBLAYOUT:-us}")
sed "s/@LAYOUT@/$layout/" "$here/deck.sway" > /etc/kimera/deck.sway
sed "s/@LAYOUT@/$layout/" "$here/greeter.sway" > /etc/kimera/greeter.sway
shot=$(su "$U" -c 'mktemp --suffix=.png')
su "$U" -c "/usr/local/bin/caretta-deck-panel --png '$shot'"
[ -s "$shot" ] || { rm -f "$shot"; echo "the deck could not draw; nothing was switched on"; exit 1; }
rm -f "$shot"
install -m 755 "$here/kimera-deck" /usr/local/bin/kimera-deck
[ -f "$here/poweroff-install.sh" ] && sh "$here/poweroff-install.sh" "$U"

# the login: greetd asks for the password with Caretta's own login screen as its face. It lives on screen 7,
# where Debian's greetd is built to run, and that screen is shown at startup. What sway says goes to a file in /tmp.
# Nobody is logged in without the password. The other screens (Ctrl+Alt+F2) and SSH stay as they are.
G=$(getent passwd _greetd >/dev/null && echo _greetd || echo greeter)
id "$G" >/dev/null
usermod -aG video,render,input "$G"
[ -f /etc/greetd/config.toml.debian ] || cp /etc/greetd/config.toml /etc/greetd/config.toml.debian 2>/dev/null || true
cat > /etc/greetd/config.toml <<C
[terminal]
vt = 7

[default_session]
command = "sh -c 'sway --config /etc/kimera/greeter.sway 2>&1 | logger -t caretta-greeter'"
user = "$G"
C
gshot=$(su -s /bin/sh "$G" -c 'mktemp --suffix=.png')
su -s /bin/sh "$G" -c "/usr/local/bin/caretta-deck-panel --png '$gshot' --login; r=\$?; rm -f '$gshot'; exit \$r" \
  && systemctl enable greetd >/dev/null 2>&1 && echo "login: on from the next restart (run as $G)" \
  || { systemctl disable greetd >/dev/null 2>&1; echo "login: the login user could not draw the screen; left OFF, the text login stays"; }

# smaller: what Caretta has no use for. Only removed when nothing else would go with it.
for p in modemmanager mesa-vulkan-drivers; do
  dpkg -s "$p" >/dev/null 2>&1 || continue
  extra=$(apt-get -s purge "$p" | awk '/^Remv /{print $2}' | grep -vx "$p" | tr '\n' ' ')
  if [ -z "$extra" ]; then apt-get purge -y -q "$p" >/dev/null && echo "removed: $p"
  else echo "kept: $p (removing it would also remove: $extra)"; fi
done
apt-get clean && echo "cleared: downloaded install files"
echo "DECK-INSTALLED (keyboard: $layout). Restart Caretta to start on the login screen."
