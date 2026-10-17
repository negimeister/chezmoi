#!/bin/bash
sudo pacman -S tailscale
sudo systemctl start tailscaled
sudo tailscale up
