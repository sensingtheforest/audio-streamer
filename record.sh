#!/bin/bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/common.sh
script_name=$(basename "${BASH_SOURCE[0]}")

# You can record multiple files simultaneously: if the pi is already recording this will still work, so no need to code for an exit. 
# Anyways, I created a recording status variable, so I can still retrieve the info.
set_record_state 1

record_timestamp=$(date +%Y-%m-%d_%H%M) # The colon for the hour would be replaced by \ -> colon is a special character in unix
record_file="$AUDIO_FOLDER/$record_timestamp.wav"

#log "\n"
log "______________RECORDING"
log "$script_name - Start recording"
sudo arecord -d $RECORD_DURATION -D mic_out_shared -c 2 -r 44100 -f S16_LE -t wav -V stereo -v $record_file
if [ -f $record_file ]; then
    log "$script_name - Recorded $record_timestamp.wav"
else
    log "$script_name - Recording failed" 
fi

set_record_state 0
