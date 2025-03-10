#!/bin/bash


# THIS INSTALLER WILL PREPARE THE RASPBERRY PI FOR STREAMING AND INSTALL THE REQUIRED LIBRARIES
# FOR RELATED TASKS (AUDIO PROCESSING, INTERNET DONGLE MANAGEMENT, SYNCHRONISING RECORDINGS TO SOLAR TIME, ETC.).


# Parameters --------------------

# Upgrading the OS can take time! Set this to 0 if you're in a rush; the streamer will probably work just as well.
UPGRADE=1

# Darkice has been updated to version 1.5, and the GitHub page mentions improvements for Icecast2 starting from version 1.4.
# If the new version causes issues or the compilation fails, flash again the OS and set this to 0 to install version 1.3 already compiled.
# Also, compiling the new version takes a while...
DARKICE_NEW_VER=1 

# If you don't intend to use MEMS microphones and instead plan to use higher-end options, such as a sound card with 
# standard mics or USB mics, you can set this to 0 to skip the kernel headers installation and avoid a reboot.
MEMS=1

#---------------------------------


# The installer will create dependencies inside the folder where the installer is launched.
PROJECT_FOLDER="$(dirname "$(realpath "${BASH_SOURCE[0]}")")" 

# These lines increase the swap memory. 
# We used the 64-bit lite OS without graphics and the default value was so low that we literally couldn't 
# run the standard system updates without freezing everything! At some common tasks like updating the locales, 
# the Rpi would get stuck. 
# It is likely that by the time you try this, the bug will be fixed - it was a crazy one... 
# But you could still need more swap memory for less common tasks like installing the kernel headers.
echo ""
echo "FIX THE SWAP MEMORY BUG IN BOOKWORM"

file="/etc/dphys-swapfile"
current_value=$(grep -o "CONF_SWAPSIZE=[0-9]\+" $file | cut -d"=" -f2)
if [ $current_value -lt 1024 ]; then
	sudo sed -i '/^CONF_SWAPSIZE=[0-9]*/s/\([0-9]\+\)/1024/' $file
	echo "Swap memory was $current_value: it was changed to 1024."
else
	echo "Swap memory is $current_value: that's fine."
fi

echo "Restarting dphys-swapfile."
sudo systemctl restart dphys-swapfile


# Now we are ready to install stuff
# The update simply refreshes the list of available packages and their versions from the repositories. 
# It's needed for the battery sensor (python3-pip), and it's way faster than upgrade so we just do it. 
sudo apt update 
if [ $UPGRADE -eq 1 ]; then  
	echo ""
	echo "UPDATE AND UPGRADE OS"
	sudo apt -y upgrade 
fi

# Autosuspend for usb periferals sounded bad for a streamer supposed to run 24/7...
echo ""
echo "DISABLE AUTOSUSPEND FOR USB DONGLE"

# Set usb device power management off. It needs reboot.
if [ -f /boot/firmware/cmdline.txt ]; then
	if sudo sed -i '1s/$/ usbcore.autosuspend=-1/' /boot/firmware/cmdline.txt; then
		echo "Usb autosuspend successfully disabled."
	fi
fi


# These are the libraries needed for the streamer and a few extra tasks:
# darkince - Streaming app. (Tested with v1.5)
# screen - Multiplexer to detach the terminal session from ssh. This is essential to keep the steam running when you disconnect from the rpi.  
# cmt - We used the Computer Music Tools to filter a little bit of high freqs in the stream but there is also a handy compressor. 
# git - For some libraries that use the git repository.
# minicom - Allows you to talk to most internet dongles. Needed only if you want to reboot the dongle from cmd line.
# usb-modeswitch - Also to solve problems with some internet dongles.
# msmtp - Barebones app to send emails.
# icecast2 - Turns the rpi into a server you can access remotely like a web page that hosts the stream player.
# In the python virtual environment:
# astral - We use this to synch tasks to solar times with our script instead of standard times via crontab. (Tested with v3.2)
# imapclient - This is needed to parse the email and download new files for remote code updates.
# adafruit-blinka and adafruit-circuitpython-ads1x15 are for the battery sensor ads1115.

mkdir $PROJECT_FOLDER && cd $PROJECT_FOLDER

echo ""
echo "INSTALL PACKAGES NEEDED FOR THE STREAMER: SCREEN CMT GIT MINICOM USB-MODESWITCH MSMTP ICECAST2"

pkgs=(screen cmt git minicom usb-modeswitch msmtp icecast2)
sudo apt install -y "${pkgs[@]}" 


echo ""
echo "INSTALL DARKICE AND THE NECESSARY LIBRARIES TO COMPILE IT (lame-3.100, libogg-1.3.5, libvorbis-1.3.7, alsa-lib-1.2.9)"


if [ $DARKICE_NEW_VER -eq 1 ]; then  
	wget https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download -O lame-3.100.tar.gz
	tar xfz lame-3.100.tar.gz
	cd lame-3.100
	./configure --with-fileio=lame --without-vorbis --disable-gtktest --enable-expopt=full --prefix=/usr
	make && sudo make install
	cd ..

	sudo apt install -y libogg-dev
	wget https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz -O libogg-1.3.5.tar.gz
	tar xfz libogg-1.3.5.tar.gz
	cd libogg-1.3.5
	./configure --prefix=/usr
	make && sudo make install
	cd ..

	wget https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz -O libvorbis-1.3.7.tar.gz
	tar xfz libvorbis-1.3.7.tar.gz
	cd libvorbis-1.3.7
	./configure --prefix=/usr
	make && sudo make install
	cd ..

	wget https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.9.tar.bz2 -O alsa-lib-1.2.9.tar.bz2
	tar xjf alsa-lib-1.2.9.tar.bz2
	cd alsa-lib-1.2.9
	./configure --prefix=/usr
	make && sudo make install
	cd ..

	wget https://github.com/rafael2k/darkice/releases/download/v1.5/darkice-1.5.tar.gz
	tar -xzf darkice-1.5.tar.gz
	cd darkice-1.5
	./configure 
	make && sudo make install
	cd ..
	
	sudo rm -rf lame-3.100 lame-3.100.tar.gz libogg-1.3.5 libogg-1.3.5.tar.gz libvorbis-1.3.7 libvorbis-1.3.7.tar.gz alsa-lib-1.2.9 alsa-lib-1.2.9.tar.bz2 darkice-1.5.tar.gz darkice-1.5
else
	# As of 3-jul-2024, this installs ver 1.3. The webpage says there are improvements for Icecast2 from ver 1.4 onwards.
	sudo apt install -y darkice
fi


echo ""
echo "CREATE PYTHON VIRTUAL ENVIRONEMENT AND INSTALL PYTHON LIBRARIES"
echo "update-code.py, solar-crontab.py, and the battery sensor need some python libs that work only with the venv from bookworm:"
echo "imapclient astral adafruit-blinka adafruit-circuitpython-ads1x15"
sudo apt install -y python3-pip
python -m venv $PROJECT_FOLDER/venv
source $PROJECT_FOLDER/venv/bin/activate
pip install imapclient
pip install astral
pip install adafruit-blinka
pip install adafruit-circuitpython-ads1x15


# To run the script that will install the mems microphones drivers (mems-drivers.sh) you need the kernel headers.
if [ $MEMS -eq 1 ]; then
	echo ""
	echo "INSTALL RASPBERRYPI-KERNEL-HEADERS"
	sudo apt install raspberrypi-kernel-headers
	read -p "Kernel headers need reboot before installing mems drivers. Reboot now? (y/n): " choice && [[ $choice == [Yy] ]] && sudo reboot
fi
