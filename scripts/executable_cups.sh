#!/bin/bash
sudo pacman -S --noconfirm cups splix
sudo systemctl start cups
#xdg-open http://localhost:631
