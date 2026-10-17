#!/bin/bash

case "$1" in

    connect)
        nmcli connection up ledongle-recovery-2020
    ;;
    read)
        curl "http://192.168.4.1/nvs/$2?type=$3&key=$4&write=0"
    ;;
    write)
        curl "http://192.168.4.1/nvs/$2?type=$3&key=$4&write=1&value=$5"
    ;;
    flash)
        curl -F firmware=@"$2" "http://192.168.4.1/upload"
        ;;
    reboot)
        curl "http://192.168.4.1/reboot"
        ;;
esac
