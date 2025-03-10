#!/bin/bash

# Replace this with your sound device. 
# Use "arecord -l" to check the name. If you see stuff in square brackets after the device name, don't incude it!
# IMPORTANT: the default bitrate of asound.conf is 32 bit, good for most MEMS mics, but you really
# need to get this one right according to your device or the audio quality will be bad. 
# For the Rode AIMicro, write here "AIMicro" and change asound.conf from S32_LE to S24_3LE
DEVICE="sndrpii2scard"

ALSAFILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/asound.conf
MICTESTFILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/mic-test.wav

echo ""
echo "CONFIGURE ALSA"

# Copy asound.conf in the right folder
if [ -f $ALSAFILE ]; then
    if sudo cp $ALSAFILE /etc/; then
		echo "asound.conf successfully copied to /etc/"
	fi
else	
	echo "Error: File $ALSAFILE does not exist."
	exit 1
fi

# This line replaces the audio device name in the alsa config file with the one specified in the var MIC.
# If you rerun this script it will work because asound.conf is copied again from the original file with the default dev name. 
sudo sed -i "s/sndrpii2scard/${DEVICE}/g" "/etc/asound.conf"

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