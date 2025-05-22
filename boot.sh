#!/bin/bash

# We are running this boot.sh with systemctl. See boot.service.txt
# With crontab @boot, we had all sorts of problems.

# This gives you the absolute path of the folder where common.sh is located. 
# TRICKY: $0 instead of ${BASH_SOURCE[0]} works when you run the script but not when you source it from terminal...
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh
script_name=$(basename "${BASH_SOURCE[0]}")

log "\n"
log "\n"
log "\line"
log "BOOT"

log "$script_name - Init state file"
init_state

set_boot_state 1
log "$script_name - BOOT_STATE=$(get_boot_state)"

# Set DNS servers (the dongle sim7600g-h wasn't resolving addresses with the nameservers assigned by network manager)
sudo chattr -i /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
# Lock /etc/resolv.conf to prevent changes from network manager
sudo chattr +i /etc/resolv.conf

log_nameservers

# Give time for devices to show up. Maybe something lower will work, but without some time the stream doesn't start at boot.
sleep 30

# These dongle models need special care...
if [[ "$DONGLE" = "brovi_e3372" ]]; then
	$PROJECT_FOLDER/dongles/reboot-dongle.sh
fi

# Check if usb0 is detected and write ip address on log. If you're using wifi, don't worry about the log.
if [[ -n "$DONGLE" ]]; then
	if ip link show usb0; then
		usb0_ip_address=$(ip addr show usb0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
		log "$script_name - Internet dongle detected as usb0. Ip address is $usb0_ip_address"
	else
		log "$script_name - Internet dongle is specified but not detected as usb0. If stream mode is 1 (wi-fi), don't worry."
		if [[ "$STREAM_MODE" -ne 1 ]]; then
			log "$script_name - Stream mode isn't wifi -> Try to get new ip address for the dongle."		
			get_new_usb0_ip
		fi
	fi
else
	log "$script_name - Internet dongle not specified. If you're using wi-fi, don't worry."
fi

# Without specifying the device, check_internet checks if internet works with any device (wlan or usb).
# If there is internet, start the streaming screen session as a daemon. Screen is needed for long-running tasks.
# arg 1: attempts (default: 3) - arg 2: interval (default 5) - arg 3: interface (optional, if empty it look for any device)
if check_internet 20 2; then
    screen -mdS $STREAM_SESSION_NAME $PROJECT_FOLDER/stream.sh
fi

# Create the audio folder if it doesn't already exist
if [ ! -d "$AUDIO_FOLDER" ]; then
  mkdir -p "$AUDIO_FOLDER"
fi

if [[ "$RECORD" -eq 1 ]]; then
	source venv/bin/activate
	screen -mdS $RECORD_SESSION_NAME python "$PROJECT_FOLDER/solar-crontab.py"
fi

sleep 30

$PROJECT_FOLDER/send-email.sh

set_boot_state 0
log "$script_name - BOOT_STATE=$(get_boot_state)"
