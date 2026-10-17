#!/bin/bash
if [ $1 = win ]; then
 PORT=19000
 DISK=/dev/nvme0n1
elif [ $1 = arch ]; then
 PORT=19001
 DISK=/dev/nvme1n1
else
 echo win or arch
 exit
fi
sudo dd if=$DISK bs=16M status=progress | taskset -c 6-11,18-23 pigz | nc ubu $PORT -N 
