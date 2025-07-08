# If you use the dongle with a data SIM card, you cannot freely ssh inside the RPi. 
# This is a workaround. Instead of loading new code and/or shell commands directly 
# to the RPi, we have the RPi downloading them from an email address. 
# Once you specify the email address and subject to look for, it will check all the email 
# in the last 7 days, and if the subject matches, it downloads all the attachments into 
# the home folder. 
# To execute shell commands, this script works with blank.sh (see blank.sh for details)

# IMPORTANT! This code doesn't take care of encryption and you write the email credentials 
# here, so make sure that access to these lines is secure, or the email address doesn't 
# contain sensitive information.


from pathlib import Path
import imaplib
import email
import os
from datetime import datetime, timedelta


# --- Email account credentials and script config (edit this section!) ---
IMAP_SERVER = "imap.gmail.com"
EMAIL_ACCOUNT = "your-email@gmail.com"
PASSWORD = "your-app-password"  # Use a Google app password, not your main account password
PROJECT_DIR = Path(__file__).resolve().parent
SEARCH_SUBJECT = "update code myProjectName"  # <-- Change to match your subject line
SEARCH_DAYS = 3  # Number of days to look back in the inbox
# ------------------------------------------------------------------------


# Ensure the directory exists
if not os.path.exists(PROJECT_DIR):
    os.makedirs(PROJECT_DIR)

log_file = os.path.join(PROJECT_DIR, "sys.log")

# Log function. If the log name is the same as your global log, just append lines.
def log_message(message):
    current_time = datetime.now().strftime('%d-%b-%Y %H:%M:%S')
    with open(log_file, 'a') as log:
        log.write(f"{current_time} - {message}\n")


log_message("______________UPDATE CODE")


# Calculate the date 7 days ago in IMAP format (DD-MMM-YYYY)
date_7_days_ago = (datetime.now() - timedelta(days=7)).strftime("%d-%b-%Y")

# Connect to email server
mail = imaplib.IMAP4_SSL(IMAP_SERVER)
mail.login(EMAIL_ACCOUNT, PASSWORD)
mail.select("inbox")  # Select the inbox

# Search for emails with the subject and date filter
search_criteria = f'(SINCE {date_7_days_ago} SUBJECT "{SEARCH_SUBJECT}")'
status, messages = mail.search(None, search_criteria)

email_ids = messages[0].split()
if not email_ids:
    log_message(f"update-code.py - No recent emails found with subject: {SEARCH_SUBJECT}")
else:
    latest_email_id = email_ids[-1]  # Get the last (most recent) email

    # Fetch the email
    status, data = mail.fetch(latest_email_id, "(RFC822)")
    msg = email.message_from_bytes(data[0][1])

    print(f"From: {msg['From']}")
    print(f"Subject: {msg['Subject']}")
    print(f"Date: {msg['Date']}")

    # Loop through email parts to find attachments
    for part in msg.walk():
        if part.get_content_disposition() == "attachment":
            filename = part.get_filename()
            if filename:
                filepath = os.path.join(PROJECT_DIR, filename)
                with open(filepath, "wb") as f:
                    f.write(part.get_payload(decode=True))
                log_message(f"update-code.py - Saved attachment: {filepath}")


# Logout
mail.logout()
print("DONE")

