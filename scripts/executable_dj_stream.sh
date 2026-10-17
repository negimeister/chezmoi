#!/bin/bash
systemctl --user stop syncthing &
killall carla

zita-j2a -c 4 -r 44100 -d hw:Platinum &
#xvfb-run --server-args="-screen 0, 1280x720x24" projectMSDL &
carla ~/music/mixxx-obs.carxp &
obs &
sleep 5
mixxx-titlehider.sh &
mixxx

kill $(jobs -p)
killall projectMSDL
killall Xvfb

carla ~/music/home_office.carxp &
systemctl --user start syncthing &
