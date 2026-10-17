#!/bin/bash
POOL=$(root_pool.sh)
tailscale-down.sh
sudo zfs mount $POOL/data/ubscale
sudo systemctl start tailscaled
sudo tailscale up
tailscale status
