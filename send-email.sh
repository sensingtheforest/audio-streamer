#!/bin/bash

# This script sends an email with attachment using an account configured on the RPi in 
# the ~/.msmtprc config file (remember to set it up before using this script!)

# Syntax: send-email.sh -a myAttachment -s "my subject" 
# Args are optional. By default it sends the sys.log with "STREAMER: Log File" subject.

# The email address is used as a common repository for remote operations like receiving 
# logs in the email from the RPi, or upload code and shell commands on the RPi.
# Remember that you need to set up ~/.msmtprc config file for this to work...

# Parameters---------------------------------

# Get the email associated with the RPi in the $HOME/.msmtprc config file. Don't change this here.
EMAIL_FROM=$(sed -n 's/^[[:space:]]*from[[:space:]]*\(.*\)/\1/p' $HOME/.msmtprc)

# This default setting sends the email to itself, but you can send emails to whoever.
EMAIL_TO="$EMAIL_FROM"

# Content of the email
EMAIL_BODY="Kindly brought to you by a very cool streamer!"

# -------------------------------------------


source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh
script_name=$(basename "${BASH_SOURCE[0]}")

# Defaults if not passed as args.
EMAIL_SUBJECT="$PROJECT_NAME: Log File"
EMAIL_ATTACHMENT="$LOG_FILE"

# Get the args (e.g. send-email.sh -a myAttachment -s "my subject") 
while getopts ":a:s:" opt; do
  case ${opt} in
    a) EMAIL_ATTACHMENT=$OPTARG;;
    s) EMAIL_SUBJECT=$OPTARG;;
    \? ) log "$script_name - Invalid flag";;
  esac
done

log "______________SEND EMAIL"

# Check if the log file exists. The var $LOG_FILE is specified in common.sh
if [ ! -f "$EMAIL_ATTACHMENT" ]; then
  log "$script_name - $EMAIL_ATTACHMENT not found"
  exit 1
fi

# Create the email content
{
  echo "To: $EMAIL_TO"
  echo "From: $EMAIL_FROM"
  echo "Subject: $EMAIL_SUBJECT"
  echo "MIME-Version: 1.0"
  echo "Content-Type: multipart/mixed; boundary=\"boundary42\""
  echo
  echo "--boundary42"
  echo "Content-Type: text/plain; charset=US-ASCII"
  echo "Content-Transfer-Encoding: 7bit"
  echo
  echo "$EMAIL_BODY"
  echo
  echo "--boundary42"
  echo "Content-Type: text/plain"
  echo "Content-Disposition: attachment; filename=\"$(basename "$EMAIL_ATTACHMENT")\""
  echo "Content-Transfer-Encoding: base64"
  echo
  base64 "$EMAIL_ATTACHMENT"
  echo "--boundary42--"
} | msmtp --from="$EMAIL_FROM" "$EMAIL_TO" >> "$EMAIL_ATTACHMENT" 2>&1

