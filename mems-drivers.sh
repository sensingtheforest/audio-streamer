#!/bin/bash

echo ""
echo "INSTALL MEMS MIC DRIVERS"

git clone https://github.com/adafruit/Raspberry-Pi-Installer-Scripts.git ~/Raspberry-Pi-Installer-Scripts
cd ~/Raspberry-Pi-Installer-Scripts/i2s_mic_module
# Who knows why they replaced this in the old code that used to work perfectly...
if grep ' simple_card_info' snd-i2smic-rpi.c; then
	sed -i 's/simple_card_info/asoc_simple_card_info/g' snd-i2smic-rpi.c
fi
make clean
make
sudo make install


# if the i2s line is commented, uncomment it
sudo sed -i '/^#.*dtparam=i2s=on/s/^#//' /boot/firmware/config.txt

# create the i2s mic config file
file="/etc/modules-load.d/snd-i2smic-rpi.conf"
if [ ! -f $file ]; then
    sudo touch $file
    echo "snd-i2smic-rpi" | sudo tee $file > /dev/null
else
	echo "$file is already there"
fi

file="/etc/modprobe.d/snd-i2smic-rpi.conf"
rpi_model=1 # 1 = rpi zero 2W,
if [ ! -f $file ]; then
    sudo touch $file
    echo "options snd-i2smic-rpi rpi_platform_generation=$rpi_model" | sudo tee $file > /dev/null
else
	echo "$file is already there"
fi

echo ""
read -p "Mems drivers need reboot. Reboot now? (y/n): " choice && [[ $choice == [Yy] ]] && sudo reboot