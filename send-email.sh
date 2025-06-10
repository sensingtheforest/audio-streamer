#!/bin/bash

# This script sends an email with attachment using an account configured on the RPi in 
# the ~/.msmtprc config file (remember to set it up before using this script!)

# Syntax: send-email.sh -a myAttachment -s "my subject" 
# Args are optional. By default it sends the sys.log with "STREAMER: Log File" subject.
# You can use multiple attachments: send-email.sh -a myAttachment1 -a myAttachment2 -s "my subject" 

# The email address is used as a common repository for remote operations like receiving 
# logs in the email from the RPi, or upload code and shell commands on the RPi.
# Remember that you need to set up ~/.msmtprc config file for this to work...

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh
script_name=$(basename "${BASH_SOURCE[0]}")


# Parameters---------------------------------

# Get the email associated with the RPi in the $HOME/.msmtprc config file. Don't change this here.
EMAIL_FROM=$(sed -n 's/^[[:space:]]*from[[:space:]]*\(.*\)/\1/p' $HOME/.msmtprc)

# This default setting sends the email to itself, but you can send emails to whoever.
EMAIL_TO="$EMAIL_FROM"

# Content of the email
EMAIL_BODY="Kindly brought to you by a very cool streamer!"

# Default project name
DEFAULT_SUBJECT="$PROJECT_NAME: Log File"
DEFAULT_ATTACHMENT=$LOG_FILE  

# -------------------------------------------


EMAIL_SUBJECT=$DEFAULT_SUBJECT
EMAIL_ATTACHMENTS=("$DEFAULT_ATTACHMENT")
ATTACHMENTS_CUSTOMIZED=false

while getopts ":a:s:" opt; do
  case ${opt} in
    a)
      if ! $ATTACHMENTS_CUSTOMIZED; then
        EMAIL_ATTACHMENTS=()  # Clear default
        ATTACHMENTS_CUSTOMIZED=true
      fi
      EMAIL_ATTACHMENTS+=("$OPTARG")
      ;;
    s) EMAIL_SUBJECT=$OPTARG;;
    \?) log "$script_name - Invalid flag";;
  esac
done

log "______________SEND EMAIL"

# Check all attachments
for attachment in "${EMAIL_ATTACHMENTS[@]}"; do
  if [ ! -f "$attachment" ]; then
    log "$script_name - Attachment $attachment not found"
    exit 1
  fi
done

# Create the email with multiple attachments
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
  
  for attachment in "${EMAIL_ATTACHMENTS[@]}"; do
    echo
    echo "--boundary42"
    echo "Content-Type: application/octet-stream"
    echo "Content-Disposition: attachment; filename=\"$(basename "$attachment")\""
    echo "Content-Transfer-Encoding: base64"
    echo
    base64 "$attachment"
  done

  echo "--boundary42--"
} | msmtp --from="$EMAIL_FROM" "$EMAIL_TO" >> "$LOG_FILE" 2>&1
