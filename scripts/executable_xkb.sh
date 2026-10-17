#!/bin/bash
#killall xcape
killall keynav
setxkbmap -layout jp -variant dvorak -option ctrl:swap_lalt_lctl,shift:both_capslock
#xcape -e "Shift_L=0x5c" -t 100
keynav &
exit 0

