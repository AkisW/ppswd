#!/bin/sh

TEMP_DIRS="/tmp /var/tmp /dev/shm"
SCRIPT_DIR=$(dirname "$0")
IS_TEMP=0

for temp_dir in $TEMP_DIRS; do
    if [ "$SCRIPT_DIR" = "$temp_dir" ]; then
        IS_TEMP=1
        break
    fi
done

if [ $IS_TEMP -eq 0 ]; then
    echo "This script must be run from a temporary directory."
    echo "Please move it to a temporary directory and run it again."
    exit 1
fi

trap 'rm -f "$0"' EXIT

opkg update
opkg install wpa_supplicant

echo "Enter the SSID:"
read SSID

echo "Enter the passphrases (separated by space):"
read -a PASSPHRASES

cat <<EOF >> /etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=0
update_config=1
fast_reauth=1
ap_scan=1

EOF

for passphrase in "${PASSPHRASES[@]}"; do
    cat <<EOF >> /etc/wpa_supplicant/wpa_supplicant.conf
network={
    ssid="$SSID"
    psk="$passphrase"
    id_str="$passphrase"
    key_mgmt=WPA-PSK
    priority=1
}

EOF
done

cat <<EOF > /usr/local/bin/assign_permissions.sh
#!/bin/sh

CONNECTED_PASSPHRASE=\$(cat /etc/wpa_supplicant/wpa_supplicant.conf | grep -A 1 "id_str" | tail -n 1 | cut -d '"' -f 2)

case "\$CONNECTED_PASSPHRASE" in
    "Passphrase1")
        echo "Assigning permissions for Passphrase1"
        ;;
    "Passphrase2")
        echo "Assigning permissions for Passphrase2"
        ;;
    *)
        echo "Unknown passphrase"
        ;;
esac
EOF

chmod +x /usr/local/bin/assign_permissions.sh

echo "post-up=/usr/local/bin/assign_permissions.sh" >> /etc/wpa_supplicant/wpa_supplicant.conf

/etc/init.d/wpa_supplicant restart
