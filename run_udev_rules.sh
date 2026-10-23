#!/usr/bin/env bash
# Deploy udev rules for peripherals: the Sofle keyboard, hidraw access, and
# probe-rs (embedded dev tools). Idempotent: a rule file is only rewritten when
# its content differs from the desired state.
set -euo pipefail

sudo mkdir -p /etc/udev/rules.d

install_rule() {
    local name="$1"
    local dest="/etc/udev/rules.d/${name}"
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
        rm -f "$tmp"
        echo "  ${name}: up-to-date"
        return 0
    fi
    sudo install -m 0644 "$tmp" "$dest"
    rm -f "$tmp"
    echo "  ${name}: updated"
}

echo "Deploying udev rules to /etc/udev/rules.d/"

install_rule 50-sofle.rules <<'EOF'
SUBSYSTEM=="usb", ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="615e", TAG+="uaccess"
SUBSYSTEM=="tty", ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="615e", TAG+="uaccess"
EOF

install_rule 60-hidraw.rules <<'EOF'
KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="3939", MODE="0666"
EOF

install_rule 69-probe-rs.rules <<'EOF'
# Copy this file to /etc/udev/rules.d/
# If rules fail to reload automatically, you can refresh udev rules
# with the command "udevadm control --reload"

# This rules are based on the udev rules from the OpenOCD project, with unsupported probes removed.
# See http://openocd.org/ for more details
#
# This file is available under the GNU General Public License v2.0

ACTION!="add|change", GOTO="probe_rs_rules_end"

SUBSYSTEM=="gpio", MODE="0660", GROUP="uucp", TAG+="uaccess"

SUBSYSTEM!="usb|tty|hidraw", GOTO="probe_rs_rules_end"

# Please keep this list sorted by VID:PID

# STMicroelectronics ST-LINK V1
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3744", MODE="660", GROUP="uucp", TAG+="uaccess"

# STMicroelectronics ST-LINK/V2
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", MODE="660", GROUP="uucp", TAG+="uaccess"

# STMicroelectronics ST-LINK/V2.1
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3752", MODE="660", GROUP="uucp", TAG+="uaccess"

# STMicroelectronics STLINK-V3
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374d", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374e", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374f", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3753", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3754", MODE="660", GROUP="uucp", TAG+="uaccess"

# SEGGER J-Link
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="0101", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="0102", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="0103", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="0104", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="0105", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="0107", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="0108", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1001", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1002", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1003", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1004", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1005", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1006", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1007", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1008", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1009", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="100a", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="100b", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="100c", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="100d", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="100e", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="100f", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1010", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1011", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1012", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1013", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1014", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1015", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1016", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1017", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1018", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1019", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="101a", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="101b", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="101c", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="101d", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="101e", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="101f", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1020", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1021", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1022", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1023", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1024", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1025", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1026", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1027", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1028", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1029", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="102a", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="102b", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="102c", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="102d", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="102e", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="102f", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1050", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1051", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1052", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1053", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1054", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1055", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1056", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1057", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1058", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1059", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="105a", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="105b", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="105c", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="105d", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="105e", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="105f", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1060", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1061", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1062", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1063", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1064", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1065", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1066", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1067", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1068", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="1069", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="106a", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="106b", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="106c", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="106d", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="106e", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1366", ATTRS{idProduct}=="106f", MODE="660", GROUP="uucp", TAG+="uaccess"

# FT232H
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", MODE="660", GROUP="uucp", TAG+="uaccess"
# FT2232x
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", MODE="660", GROUP="uucp", TAG+="uaccess"
# FT4232H
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6011", MODE="660", GROUP="uucp", TAG+="uaccess"

# FTDI-based Olimex devices
ATTRS{idVendor}=="0x15ba", ATTRS{idProduct}=="0x0003", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="0x15ba", ATTRS{idProduct}=="0x0004", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="0x15ba", ATTRS{idProduct}=="0x002a", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="0x15ba", ATTRS{idProduct}=="0x002b", MODE="660", GROUP="uucp", TAG+="uaccess"

# Espressif USB JTAG/serial debug unit
ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", MODE="660", GROUP="uucp", TAG+="uaccess"
# Espressif USB Bridge
ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1002", MODE="660", GROUP="uucp", TAG+="uaccess"

# CMSIS-DAP compatible adapters
ATTRS{product}=="*CMSIS-DAP*", MODE="660", GROUP="uucp", TAG+="uaccess"
# WCH Link (CMSIS-DAP compatible adapter)
ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="8010", MODE="660", GROUP="uucp", TAG+="uaccess"
ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="8011", MODE="660", GROUP="uucp", TAG+="uaccess"

LABEL="probe_rs_rules_end"
EOF
