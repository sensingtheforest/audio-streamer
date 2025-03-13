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

commands_script="$PROJECT_FOLDER/commands-tray.sh"
script_content=$(cat "$commands_script")

# Check if commands-tray.sh exists and is not empty
if [[ -f "$commands_script" && -s "$commands_script" ]]; then
    log "blank.sh - Executing $commands_script..."
    log "$script_content"
    source "$commands_script"
    log "blank.sh Execution completed. Deleting $commands_script..."
    sudo rm -f "$commands_script"
else
    log "No commands to execute."
fi

# Reboot if the reboot flag is set
if [[ -n "$reboot" && "$reboot" -eq 1 ]]; then
    log "Rebooting now..."
    sudo reboot
fi


#######################################
# NOTES FOR CREATING commands-tray.sh #
#######################################

# You can't use 'sudo reboot' normally to reboot in commands-tray.sh or these script won't finish.
# To reboot the RPi with commands-tray.sh, write as last command:  
# reboot=1

# To add a new cronjob remotely:
# crontab -l | { cat; echo "* * * * * echo 'ahahah' >> test.txt"; } | crontab -

# To edit an existing cronjob:
# crontab -l | sed '/a word or pattern that's only in the line to replace/c\* * * * * I'm the new cronjob' | crontab -
# E.g. if you want to change the time of "30 * * * * $HOME/Stream/monitor.sh":
# crontab -l | sed '/monitor.sh/c\15 * * * * $HOME/Stream/monitor.sh' | crontab -

# Copy the entire content of crontab to a file called blah.txt in the home folder
# crontab -l | cat >> blah.txt
# Copy the content of crontab to the project's log file
# crontab -l | cat >> "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/sys.log
# OR you can source the project functions and global vars in commands-tray.sh
# source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh
# crontab -l | cat >> "$PROJECT_FOLDER/sys.log"
