##!/bin/bash

source "$(dirname "$(dirname "$(realpath "$0")")")"/common.sh

# I wish dongles you find online could all reboot the same way... but... 

case $DONGLE in

sim7600g-h)
	
	log "Rebooting dongle..."        

	# This dongle, for us, needed the ignore command in /etc/dhcp/dhclient.conf and the static ip config.
	# All done in this function in common.sh
	# This one is also called in boot.sh if you enable static ip in the config variables, but it works here as a note too...
 	set_static_ip()

	log "You selected the dongle sim7600g-h -> Restarting dongle via minicom."
	
	{
	echo "$(date '+%d-%b-%Y %H:%M:%S') - MINICOM: send AT cmd" | tee -a $PROJECT_FOLDER/sys.log
	printf "AT\r\n" # attention please
	sleep 0.5 
	printf "AT\r\n" # again, just in case you didn't hear...
	sleep 0.5
	echo "$(date '+%d-%b-%Y %H:%M:%S') - MINICOM: send restart" | tee -a $PROJECT_FOLDER/sys.log
	printf "AT+CFUN=1,1\r\n"; # restart, it's FUN!
	sleep 18
	echo "$(date '+%d-%b-%Y %H:%M:%S') - MINICOM: exit" | tee -a $PROJECT_FOLDER/sys.log
	if [[ -n "$APN" ]]; then
		# This will set the APN: most modems do this automatically but, if something is off, 
		# or you notice that, say, your O2 SIM card works whereas the Vodafone one doesn't, 
		# try to set APN="APN_of_your_phone_provider"
		printf "AT+CGDCONT=1,\"IP\",\"%s\"\r\n" "$APN"
		sleep 2
	fi
	#printf "ATD*99#\r\n";
	#sleep 4
	printf "exit";
	} | sudo minicom -D /dev/ttyUSB2 #| tee minicom_output.txt
	
;;


brovi_e3372)

	# Copy usb_modeswitch configuration file to the right folder if it's not there yet.
	if [[ ! -f /etc/usb_modeswitch.d/3566_2001 ]]; then
		if ! sudo cp "$PROJECT_FOLDER/dongles/3566_2001" "/etc/usb_modeswitch.d/3566_2001"; then
			log "Failed to copy 3566_2001 configuration file"
			exit 1
		fi
	fi

	#  Copy 40-huawei.rules file to the right folder if it's not there yet.
	if [[ ! -f /etc/udev/rules.d/40-huawei.rules ]]; then 
		if ! sudo cp "$PROJECT_FOLDER/dongles/40-huawei.rules" "/etc/udev/rules.d/40-huawei.rules"; then
			log "Failed to copy 40-huawei.rules file"
			exit 1
		fi
	fi

	log "Configuration files for 4G dongle brovi e3372 are in place -> Restarting dongle."

	sudo usb_modeswitch -v 3566 -p 2001 -X
	sleep 2
	sudo modprobe option
	echo 3566 2001 ff | sudo tee /sys/bus/usb-serial/drivers/option1/new_id >/dev/null
	echo AT^RESET | sudo tee /dev/ttyUSB4 >/dev/null

    log "Rebooting dongle..."

    sleep 40  

    if sudo ip link set usb0 up; then
        log "usb0 is up -> systemctl restart networking to get static ip address for the device"
        sudo systemctl restart networking
        sleep 5
    fi

;;


### default case
*)
	log "ERROR: Unsupported dongle type '$DONGLE'."
	exit 1
;;


esac
