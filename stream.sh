#!/bin/bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh

start_stream() {
    if [[ $STREAM_MODE -eq 1 ]]; then
        log "start_stream() - Stream with wifi."
        stream_wifi
    elif [[ $STREAM_MODE -eq 2 ]]; then
        if [[ -n $DONGLEMODE_WIFI_WINDOW && $DONGLEMODE_WIFI_WINDOW -ne 0 ]]; then
            if [[ $DONGLEMODE_WIFI_WINDOW -lt 300 ]]; then
                log "start_stream() - DONGLEMODE_WIFI_WINDOW cannot be less than 300 -> Setting to 300 seconds"
                DONGLEMODE_WIFI_WINDOW=300
            fi
        fi
        # Try to stream with wifi (in the wilderness probably a hotspot) but if it fails try to use dongle right away. 
        # It that fails too, throw the hail mary...
        if ! stream_wifi; then
			if ! stream_dongle; then
				log "start_stream() - Trying to stream with whatever active internet device..."
				stream_whatever
			fi
        fi
        sleep 1
        log "start_stream() - Waiting $DONGLEMODE_WIFI_WINDOW sec before shutting down wifi..."
        sleep $DONGLEMODE_WIFI_WINDOW
        # This is more aggressive than "ip link set wlan0 down" and it kills wifi at hardware level. To reverse use "unblock".
        log "start_stream() - Kill wifi at hardware level: if you want to ssh, you'll have to reboot."
        sudo rfkill block wifi
        sleep 1
        # STREAMER_STEATE=2 means streaming with dongle -> if you're already streaming with the dongle, do nothing.
        if (( $(get_streamer_state) != 2 )); then
			if ! stream_dongle; then
				log "start_stream() - Trying to stream with whatever active internet device..."
				stream_whatever
			fi
        fi
    elif [[ $STREAM_MODE -eq 3 ]]; then
		log "start_stream() - Stream with whatever active internet device..."
		stream_whatever
    elif [[ $STREAM_MODE -eq 4 ]]; then
        stream_greedywifi
	else
		log "ERROR: Invalid stream mode."
    fi
}

stream_wifi() {
    if connect_to_wifi; then
        if ping -c 2 -I wlan0 8.8.8.8 >/dev/null; then
            log "stream_wifi() - Ping successful on wlan0."
            set_streamer_state 1
            # Run darkice in the background with & or the commands after this in the calling function won't execute
            start_darkice &
        else
            log "stream_wifi() - ERROR: Ping failed on wlan0."
            return 1
        fi
    else
        log "stream_wifi() - ERROR: Cannot stream with wifi."
        return 1
    fi
}

stream_dongle() {
	# If usb dongle is detected, then check internet via dongle and start darkice. 
	if ip addr show usb0; then
		if ping -c 2 -I usb0 8.8.8.8; then
			log "stream_dongle() - Ping successful on usb0."
			set_streamer_state 2
			start_darkice &
		else
			log "stream_dongle() - ERROR: Cannot stream with dongle."
			return 1
		fi
    else 
    	log "stream_dongle() - ERROR: No usb0 device found."
    fi
}

stream_whatever() {
    if ping -c 2 8.8.8.8; then
        log "stream_whatever() - Ping successful."
        set_streamer_state 3
        start_darkice &
    else
        log "stream_whatever() - ERROR: Nope, no internet."
        return 1
    fi
}

# This is a little beta and messy... but for debug in the forest it worked...
stream_greedywifi() {

	darkice_function=start_darkice

	while true; do

		log "NETWORK CHECK"
		
		if connect_to_wifi; then
			if ping -c 2 -I wlan0 8.8.8.8 >/dev/null; then
				log "stream.sh - Ping successful on wlan0."
				streamer_state=$(get_streamer_state)
	#            log "stream.sh - Streamer state with wifi = $streamer_state"
				if (( $streamer_state == 0 )); then
					log "stream.sh - Start darkice from STREAMER_STATE=0 using wifi."
					$darkice_function &
					set_streamer_state 1
				elif (( $streamer_state == 2 )); then
					log "stream.sh - Switch from dongle to wifi and restart darkice."
					kill_darkice
					sleep 1
					$darkice_function &
					set_streamer_state 1
				else
					log "stream.sh - You should already be streaming from the wifi but check darkice status." v
					if ! status_darkice; then
						kill_darkice
						sleep 1
						$darkice_function &
					fi
				fi
			else
				log "stream.sh - WARNING: Ping failed on $WIFI_SSID -> Wait for next check."
			fi
		else
			if ping -c 2 -I usb0 8.8.8.8; then
				log "stream.sh - Ping successful on usb0."
				streamer_state=$(get_streamer_state)
	 #           log "stream.sh - Streamer state with usb = $streamer_state" v
				if (( $streamer_state == 0 )); then
					log "Start darkice from STREAMER_STATE=0 using usb dongle"
					$darkice_function &
					set_streamer_state 2
				elif (( $streamer_state == 1 )); then
					log "stream.sh - Switch from wifi to usb dongle and restart darkice"
					kill_darkice
					sleep 1
					$darkice_function &
					set_streamer_state 2
				else
					log "\v stream.sh - You should already be streaming from the usb dongle but check darkice status." v
					if ! status_darkice; then
						kill_darkice
						sleep 1
						$darkice_function &
					fi
				fi
			else
				log "stream.sh - WARNING: Ping failed on usb0 -> Wait for next check."
			fi
		fi

		sleep $GREEDYWIFIMODE_INTERVAL
	done

}

monitor_stream() {
    # This loop also ensures that the screen session stays open when you call darkice with &.
    while true; do
        if status_darkice; then
            # If the dongle is specified and stream mode isn;t wi-fi, then check ip address isn't assigned or gets lost.
            # The sim7600g-h (or vodafone SIM?) seems to try to renew the address every 24hrs and looses the static one unless restart networking.
            # After restart networking, restart darkice too or it could get stuck. 
            if [[ -n $DONGLE && $STREAM_MODE -ne 1 ]]; then
                log "monitor_stream() - Dongle: $DONGLE" v
                if ! check_usb0_ip; then
                    # No ip address for the dongle. Try to get a new one.
                    get_new_usb0_ip
                    # If there is already the process running, start_darkice() kills and restart.                    
                    start_darkice &
                # This elif can happen if the connection is poor and Darkice gets stuck with "reconnect  0" or "TcpSocket" errors.
                # With wlan I never had this problem, but with the dongle it also solved the issue of the server needing manual reboot.
                # Then the less frequent monitor.sh does the same check for any connection mode.
                elif [[ $(get_darkice_state) -eq 0 ]]; then
                    log "monitor_stream() - Darkice is open but the log reported a problem -> Kill and restart darkice."
                    start_darkice &
                fi
            fi
        else
            log "monitor_stream() - DarkIce is not running -> Start stream."
            # Unlike start_darkice, start_stream also opens the screen session in which darkice will run.
            # We need to run this in the background because there are sleep commands in the functions called.
            start_stream &
        fi
        sleep $DARKICE_MONITOR_INTERVAL
    done
}

monitor_stream
