#!/bin/bash 

# This script is used to execute commands remotely when the streamer is connected to an internet dongle.
# Internet dongles don't allow you to ssh with their public address, so this is a workaround.
# The execution of this script is automated with crontab: after a new blank.sh is uploaded 
# and called, all the commands between the markers are executed and deleted.
# It works in conjunction with update-code.py: update-code.py checks a specified email address
# and uploads the attachments of the email with a specified subject in the project folder of the rpi. 
# If blank.sh is attached, the script is downloaded and then executed.

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh
SCRIPT="${BASH_SOURCE[0]}"
TEMP_FILE=$(mktemp)

# Get the lines between the markers
blank_commands=$(sed -n '/^# ---from-here---/,/^# ---to-here---/ {/^# ---from-here---\|^# ---to-here---/d; /^[[:space:]]*$/d; p}' "$SCRIPT")
# Check if there is something other than just whitespace (spaces, tabs, newlines)
if [[ -n "$(echo "$blank_commands" | tr -d '[:space:]')" ]]; then
    log "blank.sh - Executing commands..."
    # Copy all the commands to be executed on the sys log
    log "$blank_commands"
else
    log "blank.sh - There are no commands to execute."
    exit 1
fi

# WRITE HERE THE COMMANDS TO BE EXECUTED ONCE AND THEN DELETED (DON'T DELETE THE MARKERS!)
# ---from-here---





# ---to-here---

# You can't use 'sudo reboot' normally to reboot or the remaining code won't run and commands won't be deleted. 
# To reboot after the commands, write as last line:  
# reboot=1

# To add a new cronjob remotely:
# crontab -l | { cat; echo "* * * * * echo 'ahahah' >> test.txt"; } | crontab -

# To edit an existing cronjob:
# crontab -l | sed '/something that is only in the line to change/c\* * * * * echo "uhuhuhu" >> test.txt' | crontab -


log "blank.sh - Commands executed"

# ${BASH_SOURCE[0]} is the bash cmd to get the name of the current file. $0 also works here but not when sourced from terminal.
SCRIPT="${BASH_SOURCE[0]}"
TEMP_FILE=$(mktemp)

# Schedule replacement after the script finishes. If it's after sed without trap, this part gets lost.
# After deleting the executed cmds, the script is copied to a new file, so we give exec privileges.
if [[ -z $reboot || $reboot -eq 0 ]]; then
    trap 'mv "$TEMP_FILE" "$SCRIPT"; sudo chmod 755 "$SCRIPT"' EXIT
else
    # Reboot too.
    trap 'mv "$TEMP_FILE" "$SCRIPT"; sudo chmod 755 "$SCRIPT"; sudo reboot' EXIT
fi

# Use sed to remove content between the markers. Everything after this line won't be copied.
# comma for range, | is the OR, \ avoids | to be literal. 
# ^ means at the beginning of line, so the markers inside the first sed command don't mess up with this.
sed '/^# ---from-here---/,/^# ---to-here---/ {/^# ---from-here---\|^# ---to-here---\|^[[:space:]]*$/!d}' "$SCRIPT" > "$TEMP_FILE"
