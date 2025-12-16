#!/bin/bash

# This script contains all the shared functions and global variables used in the other  
# scripts. It is sourced at the beginning of each script.
# You set up here most of the parameters of the streamer.

# IMPORTANT! This code doesn't take care of encryption and you write the WiFi credentials 
# here, so make sure that access to these lines is secure, or access to the specified 
# WiFis isn't a security risk.


# Mandatory Parameters---------------------------------

STREAM_MODE=1

### 1 = wifi

### 2 = dongle with wifi window 
# This mode expects a 4g dongle with a working SIM card. It tries to connect first to one of the specified networks 
# such as a smartphone hotspot (with that you can edit the code in remote locations directly from the smartphone with Termius or similar apps). 
# After 10 minutes (you can change the window below with DONGLEMODE_WIFI_WINDOW), it will shut down the wifi capabilities of the Pi to save power. 
# You'll have to turn it off and on again to reconnect to the wifi.

### 3 = stream with whatever internet device is found first

### 4 = dongle with greedy wifi (BETA)
# In this mode, the Raspberry Pi continuously searches at regular intervals for a specified Wi-Fi network or smartphone hotspot. 
# The interval is defined by GREEDYWIFIMODE_INTERVAL, below in optional parameters. 
# When it detects the target network, it automatically switches from the dongle to the Wi-Fi connection.

# Write here the names of the WiFi networks you plan to use and their passwords.
WIFI_SSIDS=("mySmartphoneHotspot" "myLAN" "anotherWiFi")
WIFI_PWDS=("mySmartphoneHotspotPassword" "myLANPassword" "anotherWiFiPassword")

#-----------------------------------------------------


# Optional Parameters---------------------------------

PROJECT_NAME="Streamer" # Used in the email's subject when receiving the log, etc.
# This gives you the absolute path of the folder where common.sh is located. 
PROJECT_FOLDER="$(dirname "$(realpath "${BASH_SOURCE[0]}")")" 
AUDIO_FOLDER="$PROJECT_FOLDER/audio"
LOG_FILE="$PROJECT_FOLDER/sys.log"
VERBOSE=0  # If 1, all the log messages with a "v" at the end will also be written on the log.
STATE_FILE="$PROJECT_FOLDER/state.txt"
STREAM_SESSION_NAME="stream"
RECORD=1 # Use solar crontab to automate recordings. Check solar-crontab.py to change the solar times and location.
RECORD_SESSION_NAME="record"
RECORD_DURATION=300 # Duration of the automated recordings in seconds.

# The Huawei brovi_e3372 needs reboot, and it was tricky to do. If you use that one and write it here, the code will set it up automatically.
# The sim7600g-h preferred a static ip, but maybe this one could work also if you keep DONGLE set to generic...  
# You can leave it empty for home wifi, but with stream_mode = 1 (wi-fi) it will work either way.
DONGLE="generic" # Options: brovi_e3372, sim7600g-h, generic, empty (""). 
# Enable/disable dongle reboot at start. If you really need this, make sure that reboot-dongle.sh works for your device.
DONGLE_REBOOT=0
# Some internet dongles need the static IP, of they don't renew the lease. This is done and undone with functions in this script. 
STATIC_IP=0  # disable/enable static IP for the dongle
USB0_ADDRESS="192.168.225.39"  # user-configurable, it only works if static IP is enabled
# These two paths are used in the static ip functions.
DHCLIENT_CONF="/etc/dhcp/dhclient.conf"
STATIC_CONF_FILE="/etc/network/interfaces.d/usb0-static-ip"

# Interval for monitor_stream(). It checks if darkice is running, DARKICE state variable, and the dongle ip address when DONGLE isn't empty. 
# Any bad state will trigger countermeasures, but this is lighter than the monitor.sh, which is run from crontab at larger intervals.
DARKICE_MONITOR_INTERVAL=60

# This is the time after reboot you'll have to change things with ssh before the wifi shuts down at hardwere level.
# This is the most power efficient mode.
# It doesn't accept values smaller than 300 sec, otherwise if your internet dongle doesn't work good luck to ssh again...
DONGLEMODE_WIFI_WINDOW=600

# Every n seconds, the greedy wifi mode checks if there is any of the permitted wifis available.
# If there is, it connects to the wifi and restarts darkice. 
GREEDYWIFIMODE_INTERVAL=10

# If you have a usb audio device, this activates the headphones, low latency output. (Tested with AI Micro)
HEADPHONES=0

#------------------------------------------------



log() {
    local message="$1"
    local verbose_only="$2"
    local timestamp=$(date '+%d-%b-%Y %H:%M:%S')

    # If there is a "v" after the message string, then it's a verbose message and it goes to the log only if VERBOSE=1.
    if [[ "$verbose_only" == "v" ]]; then
        if [[ $VERBOSE -eq 1 ]]; then
            echo "$timestamp - $message" >> "$LOG_FILE"
        fi
    else
        case "$message" in
            "\n")
                echo "" >> "$LOG_FILE"
                ;;
            "\line")
                echo "_______________________________________" >> "$LOG_FILE"
                ;;
            *)
                echo "$timestamp - $message" >> "$LOG_FILE"
                ;;
        esac
    fi
}

# Change STREAMER_STATE in the state file
# 0 = not streaming, 1 = streaming with wifi, 2 = streaming with usb dongle
set_streamer_state() {
	local new_state=$1
	# Check if the state file exists
	if [[ -f $STATE_FILE ]]; then
		# Update the STREAMER_STATE in the state file
		sed -i "1s/STREAMER_STATE=[0-9]/STREAMER_STATE=$new_state/" $STATE_FILE
		return 0
	else
		log "State file not found. Creating new state file..."
		return 1
	fi
}

# Get STREAMER_STATE from the state file
get_streamer_state() {
	# Check if the state file exists
	if [[ -f $STATE_FILE ]]; then
		# Read the STREAMER_STATE from the state file
		local streamer_state=$(grep '^STREAMER_STATE=' $STATE_FILE | cut -d '=' -f 2)
		# In bash you need to echo to use the value in another script with var=$(get_streamer_state)...
		echo "$streamer_state"
		return 0
	else
		log "State file not found."
		return 1
	fi
}

# Change DARKICE_STATE in the state file
# 0 = not streaming, 1 = streaming
set_darkice_state() {
	local new_state=$1
	if [[ -f $STATE_FILE ]]; then
		sed -i "2s/DARKICE_STATE=[0-9]/DARKICE_STATE=$new_state/" $STATE_FILE
		return 0
	else
		log "State file not found."
		return 1
	fi
}

# Get DARKICE_STATE from the state file
get_darkice_state() {
	# Check if the state file exists
	if [[ -f $STATE_FILE ]]; then
		# Read the DARKICE_STATE from the state file
		local darkice_state=$(grep '^DARKICE_STATE=' $STATE_FILE | cut -d '=' -f 2)
		echo "$darkice_state"
		return 0
	else
		log "State file not found."
		return 1
	fi
}

# Change BOOT_STATE in the state file
# 1 = booting, 0 = normal
set_boot_state() {
local new_state=$1
	if [[ -f $STATE_FILE ]]; then
		sed -i "3s/BOOT_STATE=[0-9]/BOOT_STATE=$new_state/" $STATE_FILE
		return 0
	else
		log "State file not found."
		return 1
	fi
}

get_boot_state() {
	if [[ -f $STATE_FILE ]]; then
		local boot_state=$(grep '^BOOT_STATE=' $STATE_FILE | cut -d '=' -f 2)
		echo "$boot_state"
		return 0
	else
		log "State file not found."
		return 1
	fi
}

# Change RECORDING_STATE in the state file
# 1 = record, 0 = nope
set_record_state() {
	local new_state=$1
	if [[ -f $STATE_FILE ]]; then
		sed -i "4s/RECORD_STATE=[0-9]/RECORD_STATE=$new_state/" $STATE_FILE
		return 0
	else
		log "State file not found."
		return 1
	fi
}

get_record_state() {
	if [[ -f $STATE_FILE ]]; then
		local record_state=$(grep '^RECORD_STATE=' $STATE_FILE | cut -d '=' -f 2)
		echo "$record_state"
		return 0
	else
		log "State file not found."
		return 1
	fi
}

# This is called in the boot script
init_state() {
	if [[ -f $STATE_FILE ]]; then
		set_streamer_state 0
		set_darkice_state 0
		set_boot_state 0
		set_record_state 0
	else
		echo "init_state() - State file doesn't exist -> Creating state file with default values..."
		echo "STREAMER_STATE=0" > $STATE_FILE
		echo "DARKICE_STATE=0" >> $STATE_FILE
		echo "BOOT_STATE=0" >> $STATE_FILE
		echo "RECORD_STATE=0" >> $STATE_FILE
	fi
}

kill_stream() {
    # Check if there are screen sessions running darkice and kill
    log "kill_stream() - Kill existing screen sessions running darkice: it will close both stream main loop and darkice in it."
    screen -ls | grep "[0-9]*\.$STREAM_SESSION_NAME" | while read -r kill_darkice_line; do
        #echo "$kill_darkice_line" | tee -a "$LOG_FILE"
        session_id=$(echo "$kill_darkice_line" | cut -d. -f1)
        screen -S "$session_id" -X quit
    done
    # Check if there are stream processes left open and kill
    if ps aux | grep stream.sh | grep -v grep; then 
        log "kill_stream() - Kill stream processes left."
        pkill -f stream.sh
    else
        log "kill_stream() - There is no stream process left to kill." v
    fi
    # Check if there are darkice processes left open and kill
    if ps aux | grep darkice | grep -v grep; then 
        sudo killall -9 darkice
        set_darkice_state 0
    fi
}

kill_darkice() {
	if ps aux | grep darkice | grep -v grep; then 
		log "Existing darkice processes detected -> Kill all. Screen sessions and eventual main loops will stay open."
		sudo killall -9 darkice &>/dev/null
		set_darkice_state 0
		sleep 1
		return 0
	else
		log "There are no open darkice processes." v
		return 0
	fi
}

status_darkice() {
    if sudo pidof darkice &>/dev/null; then
    	# I used this everywhere, so if you use verbose log (VERBOSE=1), it'll populate most of the log lines...
        log "status_darkice() - Darkice is running." v
        return 0
    else
        log "status_darkice() - Darkice is not running."
        # Setting here the negative state can look redundant but this is critical info and some redundancy can help. 
        # Don't set the positive state in state.txt because the active process doesn't mean that it's streaming correctly. 
        # For that, it's better to parse the darkice's output, see start_darkice()
        set_darkice_state 0
        return 1
    fi
}

start_darkice_np() {
    if ! status_darkice; then
        log "Start darkice without parse"
        sudo darkice -c $PROJECT_FOLDER/darkice.cfg -v 6 >> "$LOG_FILE" 2>&1
    else
        log "Darkice without parse is already running -> kill and restart"
        kill_darkice
        sleep 1
        sudo darkice -c $PROJECT_FOLDER/darkice.cfg -v 6 >> "$LOG_FILE" 2>&1
    fi
    set_darkice_state 1
}

start_darkice() {
    if status_darkice; then
        log "start_darkice() - Darkice already running -> Kill and restart"
        kill_darkice
    fi
    log "start_darkice() - Start darkice with real-time output line check"
    sudo darkice -c "$PROJECT_FOLDER/darkice.cfg" -v 6 | while IFS= read -r darkice_line; do
        echo "$darkice_line" | tee -a "$LOG_FILE"
        if [[ "$darkice_line" == *"reconnecting  0"* || "$darkice_line" == *"TcpSocket"* || "$darkice_line" == *"No such device"* ]]; then
            set_darkice_state 0
        elif [[ "$darkice_line" == *"SCHED_FIFO"* ]]; then
            set_darkice_state 1
        fi
        sleep 0.1
    done
}

# Check if the specified network is in the list of available Wi-Fi networks
ssid_exists() {
    local ssid="$1"
    if sudo nmcli dev wifi list | grep -F -q "$ssid"; then
        log "ssid_exists() - Network '$ssid' is available." v
        return 0  # Network available, return success
    else
        log "ssid_exists() - Network '$ssid' is not available." v
        return 1  # Network not available, return failure
    fi
}

# Log contents of /etc/resolv.conf, it contains the current nameservers.
log_nameservers() {
    log "The nameservers are:"
    while IFS= read -r line; do
        log "$line"
    done < /etc/resolv.conf
}

check_internet() {

    local attempts=${1:-3}  # Arg1 - Number of ping attempts, default is 3.
    local interval=${2:-5}  # Arg2 - Interval between ping attempts in seconds, default is 5.
    local interface=${3:-}  # Arg3 - Network interface, optional.

    local i
    for ((i=1; i<=$attempts; i++)); do
        if [[ -n "$interface" ]]; then 
            if ping -c 2 -I $interface 8.8.8.8 >/dev/null; then
                log "check_internet() - Ping successful on attempt $i using interface $interface"
                return 0  # Success
            else
                log "check_internet() - Ping failed on attempt $i using interface $interface -> retrying in $interval seconds..."
                sleep "$interval"
            fi
        else
            if ping -c 2 8.8.8.8 >/dev/null; then
                log "check_internet() - Ping successful on attempt $i"
                return 0  # Success
            else
                log "check_internet() - Ping failed on attempt $i, retrying in $interval seconds..."
                sleep "$interval"
            fi
        fi
    done

    log "check_internet() - ERROR: All ping attempts failed."
    return 1  # Failure

}

# Check usb0 IP address
check_usb0_ip() {
    usb0_ip_address=$(ip addr show usb0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    if [ -z "$usb0_ip_address" ]; then
    	log "check_usb0_ip() - ERROR: No IP address assigned to usb0."
    	return 1
    else
        log "check_usb0_ip() - usb0 ip address: $usb0_ip_address" v
        return 0
    fi
}

# Try to get new usb0 IP address. This one is called only when check_usb0_ip fails.
get_new_usb0_ip() {
	sudo ip link set usb0 up
	log "Trying systemctl restart networking to get IP address..."
	sudo systemctl restart networking
	sleep 2
	usb0_ip_address=$(ip -4 addr show usb0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
	if [ -n "$usb0_ip_address" ]; then
		log "New IP from systemctl restart: $usb0_ip_address"
		return 0
	fi

	log "systemctl restart networking failed — falling back to dhclient..."
	sudo dhclient -r usb0 2>/dev/null
	sudo ip addr flush dev usb0
	sudo rm -f /var/lib/dhcp/dhclient.leases
	sudo dhclient usb0
	sleep 2
	usb0_ip_address=$(ip -4 addr show usb0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
	if [ -n "$usb0_ip_address" ]; then
		log "New IP from dhclient: $usb0_ip_address"
		return 0
	else
		log "ERROR: Still no IP after fallback."
		return 1
	fi
}
				
# Check permitted SSIDs (WIFI_SSIDS[]) and connect if necessary
connect_to_wifi() {

    sudo nmcli dev wifi rescan
    sleep 2

    local i
    for i in "${!WIFI_SSIDS[@]}"; do
        wifi_ssid="${WIFI_SSIDS[i]}"
        wifi_password="${WIFI_PWDS[i]}"
        if ssid_exists "$wifi_ssid"; then
            current_ssid=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d':' -f2)
            if [[ "$current_ssid" == "$wifi_ssid" ]]; then
                log "connect_to_wifi() - You're already connected to '$wifi_ssid'." v
                return 0
            else
                if sudo nmcli device wifi connect "$wifi_ssid" password "$wifi_password"; then
                    log "connect_to_wifi() - Connected to '$wifi_ssid'."
                    sleep 2
                    return 0
                else
                    log "connect_to_wifi() - ERROR: Failed to connect to '$wifi_ssid'."
                    return 1
                fi
            fi
        fi
    done

    log "Network '${WIFI_SSIDS[*]}' is not available."
    return 1

}


set_static_ip() {
	# Make sure folder exists
    sudo mkdir -p /etc/network/interfaces.d

    # Add ignore block if missing
    if ! grep -q '^interface "usb0" {' "$DHCLIENT_CONF"; then
        log "Adding usb0 ignore block to $DHCLIENT_CONF"
        echo -e '\ninterface "usb0" {\n    ignore;\n}' | sudo tee -a "$DHCLIENT_CONF" >/dev/null
    else
        log "usb0 ignore block already present in $DHCLIENT_CONF"
    fi

    # Create static IP config
    cat > "$STATIC_CONF_FILE" <<EOF
auto lo
iface lo inet loopback

auto usb0
iface usb0 inet static
    address $USB0_ADDRESS
    netmask 255.255.255.0
    gateway 192.168.225.1
    dns-nameservers 8.8.8.8 8.8.4.4
    metric 100
EOF

    log "Static IP config for usb0 created at $STATIC_CONF_FILE"

    # Remove any old DHCP leases
    if [ -f /var/lib/dhcp/dhclient.leases ]; then
        log "Removing existing DHCP leases"
        sudo rm -f /var/lib/dhcp/dhclient.leases
    fi

    sudo systemctl restart networking
}

unset_static_ip() {
    sudo sed -i '/^interface "usb0" {/,/^}$/d' "$DHCLIENT_CONF"
    sudo rm -f "$STATIC_CONF_FILE"
    sudo systemctl restart networking
}

