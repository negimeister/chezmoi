#!/bin/bash
set -euxo pipefail
hdparm --user-master u --security-set-pass Eins $1
hdparm --user-master u --security-erase Eins $1
hdparm -I $1
