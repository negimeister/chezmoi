#!/bin/sh
CLASS="dropdown-term"
OPEN=$(hyprctl clients | grep $CLASS)
[ -z "$OPEN" ] && kitty --class $CLASS \
	-e sh -c 'zellij attach -t hypr || zellij new-session -s hypr -e "export HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE"' ||
	zellij detach -s hypr
