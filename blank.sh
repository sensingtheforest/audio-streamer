#!/bin/bash 

# This script is used to execute commands remotely when the streamer is connected via an internet dongle.
# It looks for a file called `commands-tray.sh` in the project folder and executes its content.
# Internet dongles do not allow SSH access via their public IP address, so this serves as a workaround.
# The execution of `blank.sh` is automated using crontab and works in conjunction with `update-code.py`.
# Whenever the file `commands-tray.sh` is found in the project folder and `blank.sh` is triggered via crontab,
# the commands within `commands-tray.sh` are executed, and the file is deleted afterward.
# `update-code.py` checks a specified email address, downloads attachments with a specified subject,
# and saves them in the project folder on the Raspberry Pi. If `commands-tray.sh` is attached, 
# it is downloaded and then executed by `blank.sh`.

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh
script_name=$(basename "${BASH_SOURCE[0]}")

commands_script="$PROJECT_FOLDER/commands-tray.sh"
# Create temp log to capture errors from the sourced commands script
temp_log=$(mktemp)

# Check if commands-tray.sh exists and is not empty and execute its commands
if [[ -f "$commands_script" && -s "$commands_script" ]]; then
    log "$script_name - Executing $commands_script..."
    log "$(cat $commands_script)"
    # Run the script in current shell (source and not bash), capture both stdout and stderr
    source "$commands_script" > >(tee -a "$temp_log") 2>&1
    # Log the full output
    log "$(cat "$temp_log")"
    log "$script_name - Execution completed. Deleting $commands_script..."
    sudo rm -f "$commands_script" && rm -f "$temp_log"
else
    log "$script_name - No commands to execute."
fi

# Reboot if the reboot flag is set
if [[ -n "$reboot" && "$reboot" -eq 1 ]]; then
    log "$script_name - Rebooting now..."
    sudo reboot
fi


#######################################
# NOTES FOR CREATING commands-tray.sh #
#######################################

# You can´t use ´sudo reboot´ normally to reboot in commands-tray.sh or these script won´t finish.
# To reboot the RPi with commands-tray.sh, write as last command:  
## reboot=1

# Change mic volume
## amixer set MicBoost 60%

# Add a new cronjob remotely:
## crontab -l | { cat; echo "* * * * * echo 'ahahah' >> test.txt"; } | crontab -

# commands-tray.sh is executed with source so it inherits all the variables and functions from the prent script.
# The var PROJECT_FOLDER and the log function are defined in common.sh 
## echo $PROJECT_FOLDER
## log $PROJECT_FOLDER

# Edit an existing cronjob:
## crontab -l | sed '/a word or pattern that's only in the line to replace/c\* * * * * I'm the new cronjob' | crontab -
# E.g. if you want to change the time of "30 * * * * $PROJECT_FOLDER/monitor.sh":
## crontab -l | sed '/monitor.sh/c\15 * * * * $PROJECT_FOLDER/monitor.sh' | crontab -

# Copy the entire content of crontab to a file called blah.txt in the home folder
## crontab -l | cat >> blah.txt
# Copy the content of crontab to the project´s log file
## crontab -l | cat >> "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/sys.log
# OR you can source the project functions and global vars again in commands-tray.sh
## crontab -l | cat >> "$PROJECT_FOLDER/sys.log"

# Send the sys.log to the email address next time blank.sh is executed. 
# When I uploaded send-email.sh remotely it needed permission first. Errors from commands-tray.sh are copied in sys.log
## sudo chmod 755 $PROJECT_FOLDER/send-email.sh
## $PROJECT_FOLDER/send-email.sh
# Send the battery.log
## $PROJECT_FOLDER/send-email.sh -a $PROJECT_FOLDER/battery.log -s "STREAMER: Battery Log."

# TEST BEFORE! This should delete all recordings older than 30 days
## find $PROJECT_FOLDER/audio -type f -mtime +30 -exec rm {} \;

# This will remove the dash from the log message in the update-code.py
## sed -i '/______________UPDATE CODE/c\log_message("UPDATE CODE")' $PROJECT_FOLDER/update-code.py
