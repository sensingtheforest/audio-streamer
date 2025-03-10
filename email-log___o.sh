#!/bin/bash

# Keep in mind that for msmtp to work you need to edit the $HOME/.msmtprc config file.

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh

log "______________EMAIL LOG"

# Configuration 
EMAIL_TO="theEmailYouSendTheLogTo"
EMAIL_FROM="theEmailAcountYouAreUsingOnThePiProbablySameAsAbove"
EMAIL_SUBJECT="YOUR STREAMER: Log File"
EMAIL_BODY="Kindly brought to you by a very cool streamer!"

# Check if the log file exists. The var $LOG_FILE is specified in common.sh
if [ ! -f "$LOG_FILE" ]; then
  echo "Log file not found: $LOG_FILE"
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
  echo "Content-Disposition: attachment; filename=\"$(basename "$LOG_FILE")\""
  echo "Content-Transfer-Encoding: base64"
  echo
  base64 "$LOG_FILE"
  echo "--boundary42--"
} | msmtp --from="$EMAIL_FROM" "$EMAIL_TO" >> "$LOG_FILE" 2>&1
