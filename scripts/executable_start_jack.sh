#!/bin/bash
jack_control start
nohup alsa_out -d hw:1 -j internal &
sleep 2
jack_connect "PulseAudio JACK Sink:front-left" "internal:playback_1"
jack_connect "PulseAudio JACK Sink:front-right" "internal:playback_2"
amixer -D hw:1 sset 'Master' 100
