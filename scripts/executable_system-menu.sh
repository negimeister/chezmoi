#!/bin/bash

chosen=$(printf "\U000f033e Lock (l)\n\U000f0343 Logout (e)\n\U000f04b2 Switch User (u)\n\U000f0904 Suspend (s)\n\uf186 Hibernate (h)\n\U000f0709 Reboot (r)\n\uf011 Shutdown (S)" |
    wofi --show dmenu --prompt "System" --insensitive --hide-scroll)

case "$chosen" in
  *"(l)"*) swaylock ;;
  *"(e)"*) hyprctl dispatch exit ;;
  *"(u)"*) dm-tool switch-to-greeter ;;
  *"(s)"*) systemctl suspend ;;
  *"(h)"*) systemctl hibernate ;;
  *"(r)"*) systemctl reboot ;;
  *"(S)"*) systemctl poweroff ;;
esac
