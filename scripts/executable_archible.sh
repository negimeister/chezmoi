#!/bin/bash
docker run  -v /data/var/cache/archible/:/build -v ~/.ssh/id_rsa:/ssh_id -v /dev:/dev -v /tmp:/out -v ~/projects/archible/vault_pass:/vault_pass -it --rm --privileged negimeister/archible:latest $@
