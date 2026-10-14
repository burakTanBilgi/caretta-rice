#!/bin/sh
# Installs the desktop pieces from Debian's own repository. Run as root.
# Sway (screen), foot (terminal), Firefox ESR, Thunar (files), wmenu (launcher), btop (tasks),
# swaybg/swaylock/grim (ground, lock, screenshots). No login manager: sway starts from the text login.
set -e
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
apt-get update -q
apt-get install -y -q --no-install-recommends sway foot firefox-esr thunar wmenu btop \
  swaybg swaylock grim xdg-desktop-portal-wlr fonts-dejavu-core fonts-noto-core \
  libgl1-mesa-dri seatd
usermod -aG video,render,input "$(getent passwd 1000 | cut -d: -f1)" 2>/dev/null || true
echo "DECK-PACKAGES-DONE"
