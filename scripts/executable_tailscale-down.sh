#!/bin/bash
sudo tailscale down
sudo systemctl stop tailscaled
sudo zfs unmount /var/lib/tailscale
