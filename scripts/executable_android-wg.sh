#!/bin/bash
curl -o /tmp/wireguard.apk https://download.wireguard.com/android-client/com.wireguard.android-1.0.20230707.apk
adb install /tmp/wireguard.apk
adb push ~/scripts/mitmwg.conf /sdcard/Download/
adb push ~/scripts/mitmproxy-ca-cert.cer.crt /storage/emulated/0/Download/mitmproxy-ca-cert.cer.crt
