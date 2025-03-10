#!/bin/bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh

tail -n 50000 "$LOG_FILE" > temp_log_file.log && mv temp_log_file.log "$LOG_FILE"
