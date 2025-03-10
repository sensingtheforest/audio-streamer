#!/bin/bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh

# This check is separate from monitor.sh because reboot also sends the log email, and too many emails are annoying...
# With crontab you can decide how often to call this last resource.
if [[ ! status_darkice || $(get_darkice_state) -eq 0 ]]; then 
	log "nuclear-option.sh - DARKICE IS UP TO NO GOOD -> SELF DESTRUCTION (no worries, just a reboot...)"
	sudo reboot
fi

# If you specified a dongle in common.sh and stream mode isn't wi-fi, then...
if [[ -n $DONGLE && $STREAM_MODE -ne 1 ]]; then
	# Check if the usb dongle is detected. 
	if ! ip addr show usb0; then
		log "nuclear-option.sh - ERROR: No usb0 device found -> REBOOT THE RPI!"
		sudo reboot
	fi
fi