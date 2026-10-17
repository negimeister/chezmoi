#!/bin/bash
for line in $(nmcli connection show | grep -oE 'wg0(\([0-9]*\))?'); do 
	nmcli connection modify "$line" connection.autoconnect false
 done
