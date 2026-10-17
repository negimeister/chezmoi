#!/bin/bash
aseqdump -l | grep $1 | awk -F: '{print $1}'
