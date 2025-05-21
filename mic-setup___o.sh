#!/bin/bash

# This script edits the asound.conf file in the project folder and copies it to /etc/, where it is required.
# If you prefer to edit asound.conf manually, make sure to modify the one in /etc/ — changes to the local copy won't take effect.

# Replace DEVICE and FORMAT according to your sound device.
# Use "arecord -l" to check the device name. If you see anything in square brackets after the name, don't include it!
# IMPORTANT: The default format in asound.conf is S32_LE (32-bit little-endian), which works well for most MEMS microphones.
# However, you must set this correctly for your specific device, or the audio quality will be poor.
# Finding the exact format label can be tricky. If standard ones like S16_LE or S24_LE don't work,
# you can install PipeWire and use its tools to detect the correct format.

DEVICE="AIMicro"
FORMAT="S24_3LE"

# TESTED DEVICES
# RØDE AI-Micro -> DEVICE="AIMicro", FORMAT="S24_3LE"
# MEMS mics with AdaFruit drivers -> DEVICE="sndrpii2scard", FORMAT="S32_LE" 

# -----------------------------------------------------------------------


ALSAFILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/asound.conf"
MICTESTFILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/mic-test.wav"

echo ""
echo "CONFIGURE ALSA"

# Copy asound.conf to the correct system folder
if [ -f "$ALSAFILE" ]; then
    if sudo cp "$ALSAFILE" /etc/; then
        echo "asound.conf successfully copied to /etc/"
    fi
else    
    echo "Error: File $ALSAFILE does not exist."
    exit 1
fi

# Replace the default device name and format in asound.conf
# This works even on repeated runs because the file is reset from the original each time
sudo sed -i "s/sndrpii2scard/${DEVICE}/g" "/etc/asound.conf"
sudo sed -i "s/S32_LE/${FORMAT}/g" "/etc/asound.conf"

echo "Restart alsa-utils"
sudo /etc/init.d/alsa-utils restart


echo ""
echo "MIC TEST"
echo "Record 10 seconds. This will activate the alsa drivers and then you should see the MicRecBoost slider if you go in the alsamixer"

arecord -d 10 -D mic_out_shared -c 2 -r 44100 -f S16_LE -t wav -V stereo -v $MICTESTFILE
sleep 2

# This is for the mems mics, which are very quiet. With any other mic, you should be fine with the "capture" fader in alsamixer.
if [[ "$DEVICE" == "sndrpii2scard" ]];then
	amixer set MicBoost 60%
fi
