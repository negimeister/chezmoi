#!/bin/bash
tailscale-down.sh
sudo zfs mount framework/data/negiscale
sudo systemctl start tailscaled
sudo tailscale up
tailscale status
