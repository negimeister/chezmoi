#!/bin/bash
grep -oP 'zfs=\K[^/]+' /proc/cmdline
