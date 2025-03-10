# Raspberry Pi Online Audio Streamer

## Description

This code turns a Raspberry Pi into an online audio streamer. Some of its features include automated recording or other tasks based on solar times and remote code updates or shell command execution using an internet dongle in remote. The installer is designed to work with Raspberry Pi OS and uses up-to-date libraries as of this release.

## Features

* Automated recording or tasks based on solar times
* Remote code updates and shell command execution
* Support for ADS1115 battery sensor
* Support for MEMS microphones
* Icecast2 streaming server integration

## Installation

### Hardware Requirements

* Raspberry Pi (tested on Raspberry Pi Zero 2 W with Raspberry Pi OS Lite 64-bit, released on 2024-11-19)
* Audio capture device (usb microphones, MEMS microphones, or usb audio device with standard microphones)

### Prerequisites

1. If using the ADS1115 battery sensor, enable I2C:

```
sudo raspi-config -> Interface Options -> I2C
```
2. If using MEMS microphones, enable I2S:

```
sudo raspi-config -> Interface Options -> I2S
```
### Setup

1. Download the project folder to your Raspberry Pi's home directory.
2. Configure settings:
    * Edit all files ending in "___o" with your settings (settings are commented inside each file).
    * Save them without "___o" (e.g., edit `common___o.sh` and save as `common.sh`).
    * **Note**: You can keep the originals, only those without `"___o"` will be used.
3. Run the installer from the project folder:
    ```
    ./install.sh
    ```
    * When prompted, configure Icecast (after the first prompt, you can use all the default settings or change passwords).
    * Reboot when asked.
    * **Note**: The script should install all required packages from the repositories. All the packages are listed in the script. There are some parameters at the beginning of install.sh you can set to spare some time, otherwise it will do a full OS upgrade and compile the latest darkice version. This may take a while - get a cup of tea... or two... 
4. For MEMS microphones, install drivers:
    ```
    ./mems-drivers.sh
    ```
    * Reboot when prompted (type `y`).
    * **Note**: If not using MEMS microphones, skip to step 5. 
5. Set up the microphone:
    ```
    ./mic-setup.sh
    ```
    * **Note**: This step assumes that you created correctly `mic-setup.sh` with your audio device info from the `___o file`.
    * A 10-second recording test will start. You should see volume meters (or a vague memory of them) moving. Check for `mic-test.wav` in the project folder. 
6. Test the stream:
    ```
    ./stream.sh
    ```
    * If set up correctly, you should be able to access the stream via your Icecast2 server address.
    * **Note**: This assumes that `darkice.cfg` has been set up correctly, there are no errors in the terminal, and the last line ends with `SCHED_FIFO`.
7. Enable email operations:
    * Follow instructions in `msmtprc.txt` to configure email account on the RPi.
8. Set up cronjobs:
    * Follow instructions in `crontab.txt`. 
9. Create boot service:
    * See `boot.service.txt` for details on setting up the streamer to start at boot.
10. ENJOY!

## Troubleshooting

* Most TCP socket errors are caused by incorrect Darkice configurations or issues with the 4G dongle.
* For LAN streaming, the address to write in the browser to stream online will be similar to `http://192.168.0.100:8000`. Note http instead of https: in most cases, https won't resolve the address.
* For remote streaming with a 4G dongle, use a streaming server provider like StreamUp, which will provide a public IP address, port, and stream password to use in the `darkice.cfg` file (the address will look more like `178.23.45.144:8063`).

## Dependencies

The following libraries and tools are required for the streamer and additional tasks.  
**Note:** Dependencies are automatically installed by the provided installer. No manual installation should be required.  


### System Packages
- [DarkIce](http://www.darkice.org/) – Streaming app. *(Tested with v1.5)*  
- [screen](https://www.gnu.org/software/screen/) – Multiplexer to detach the terminal session from SSH. This is essential to keep the stream running when you disconnect from the Raspberry Pi.  
- [CMT (Computer Music Tools)](https://packages.debian.org/sid/cmt) – Used to filter the stream.  
- [Git](https://git-scm.com/) – Required for some libraries that use Git repositories.  
- [Minicom](https://linux.die.net/man/1/minicom) – Allows communication with most internet dongles. Needed only if you want to reboot the dongle from the command line.  
- [USB_ModeSwitch](http://www.draisberghof.de/usb_modeswitch/) – Helps resolve issues with certain internet dongles.  
- [msmtp](https://marlam.de/msmtp/) – A lightweight application for sending emails.  
- [Icecast2](https://icecast.org/) – Turns the Raspberry Pi into a streaming server accessible remotely like a web page.  
- [Adafruit I2S MEMS Mic Drivers](https://github.com/adafruit/Raspberry-Pi-Installer-Scripts/tree/main/i2s_mic_module) – Required for MEMS/I2S microphones.

### Python Virtual Environment Packages  
- [Astral](https://pypi.org/project/astral/) – Used to sync tasks to solar times instead of standard times via crontab. *(Tested with v3.2)*  
- [IMAPClient](https://pypi.org/project/IMAPClient/) – Required to parse emails and download new files for remote code updates.  
- [Adafruit Blinka](https://github.com/adafruit/Adafruit_Blinka) & [Adafruit CircuitPython ADS1x15](https://github.com/adafruit/Adafruit_CircuitPython_ADS1x15) – Necessary for the ADS1115 battery sensor.  



## Additional Information

For tutorials and details about hardware and code, visit [Sensing the Forest](https://sensingtheforest.github.io).

## License

BSD-3-Clause license

## Contribution Guidelines

Coming soon.

## Credits and Acknowledgements

* **Author**: [Luigi Marino](https://github.com/luigimarino)
Developed the Raspberry Pi online audio streamer project.

* **Funder**:
[Sensing the Forest](https://sensingtheforest.github.io/) is a project funded by the [UKRI Arts and Humanities Research Council (AHRC)](https://www.ukri.org/councils/ahrc/) (AH/X011585/1, AH/X011585/2).

* **Contributors**:
  - [Anna Xambó Sedo](https://github.com/axambo) 
  - [Pete Batchelor](https://peterb.dmu.ac.uk/)

* **Acknowledgements**:
  - [LocuSonus Project](https://locusonus.org)
  - [Alice Eldridge](https://profiles.sussex.ac.uk/p127749-alice-eldridge)
