#!/bin/bash

# This script monitors the state of the streambox and tries to solve the problems it finds.

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh
script_name=$(basename "${BASH_SOURCE[0]}")

# While the streamer is booting, don't execute the monitoring script: useful if monitor is called with crontab.
if [[ $(get_boot_state) -eq 1 ]]; then
	exit
fi

# Write on a separate log file the uptime info. 
# The main log is long and messy, so if you want clean stats this is useful.
# Ensure the file exists, create if not.
touch "$PROJECT_FOLDER/uptime.log" 
# Without args, check_internet tries 3 times at 5 sec intervals.
if check_internet; then
	internet_state=1
else
	internet_state=0
fi
# Append to uptime.log the current date, internet state, darkice state (this is also set by output line parse in start_darkice())
echo "$(date '+%d-%b-%Y %H:%M:%S'), $internet_state, $(get_darkice_state)" >> "$HOME/Stream/uptime.log"


#log "\n"
log "______________MONITOR"

# Check internet connection.
if ! check_internet; then
    # If stream mode isn't 1 (wi-fi), check how the dongle is doing. If it's wi-fi, try to reconnect to the network.
    if [[ "$STREAM_MODE" -ne 1 ]]; then
        # If the usb dongle is specified in common.sh, check if there is a problem there.
        if [[ -n "$DONGLE" ]]; then
            # Check dongle ip address
            if ! check_usb0_ip; then
                get_new_usb0_ip
            fi
            if ! check_internet usb0; then
                log "$script_name - ERROR: No internet on usb0 after systemctl restart networking -> Rebooting dongle..."
                if [[ "$DONGLE_REBOOT" -eq 1 ]]
                    screen -mdS dongle $PROJECT_FOLDER/dongles/reboot-dongle.sh 
                    sleep 45
                fi
            fi
        fi
    else
        if ! connect_to_wifi; then
            log "$script_name - ERROR: Unable to connect to any of the specified wi-fi networks."
        fi
    fi
    # If the countermeasures worked, restart darkice to clean up... 
    if check_internet; then
        # kill_stream is more aggressive than kill_darkice and closes also the screen session running darkice.
        kill_stream
        sleep 1
        screen -mdS $STREAM_SESSION_NAME $PROJECT_FOLDER/stream.sh
    fi
fi

# When we deployed this streamer in the forest, with shaky network coverage, darkice sometimes stayed open but stuck. 
# The function status_darkice only checks if the process is running, so here we check also DARKICE_STATE set from start_darkice().
log "$script_name - DARKICE_STATE=$(get_darkice_state), STREAMER_STATE=$(get_streamer_state)"
if [[ ! status_darkice || $(get_darkice_state) -eq 0 ]]; then
	log "$script_name - Darkice isn't streaming -> Kill and restart stream session and log audio device info."
	# kill_stream is more aggressive than kill_darkice and closes also the screen session running darkice.
	kill_stream
	sleep 1
	screen -mdS $STREAM_SESSION_NAME $PROJECT_FOLDER/stream.sh
	# Log the available audio devices for debug
	arecord -l >> "$LOG_FILE"
fi

# If recording is on (RECORD=1 in common.sh), check if solar-crontab.py is running
if [ "$RECORD" -eq 1 ]; then
	if ! pgrep -f "solar-crontab.py" > /dev/null; then
		log "$script_name - solar-crontab.py is not running -> Restarting session..."
		screen -mdS $RECORD_SESSION_NAME python "$PROJECT_FOLDER/solar-crontab.py"
	fi
fi

#log_nameservers
