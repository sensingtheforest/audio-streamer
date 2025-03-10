from pathlib import Path
from datetime import datetime
import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn



# Log files path
PROJECT_DIR = Path(__file__).resolve().parent  # Absolute path of the script's directory
log_file = PROJECT_DIR / "sys.log"
batt_log_file = PROJECT_DIR / "battery.log"
# Ensure the directory exists
PROJECT_DIR.mkdir(parents=True, exist_ok=True)
# Create log files if they don’t exist
log_file.touch(exist_ok=True)
batt_log_file.touch(exist_ok=True)

# Log function. If the log name is the same as your global log, just append lines.
def log_message(message):
    current_time = datetime.now().strftime('%d-%b-%Y %H:%M:%S')
    with open(log_file, 'a') as log:
        log.write(f"{current_time} - {message}\n")


# Create I2C bus
i2c = busio.I2C(board.SCL, board.SDA)

# Create ADS1115 object
ads = ADS.ADS1115(i2c)

# Set the gain to handle voltages up to 4.096V (ADS1115 reference voltage)
ads.gain = 1  # Gain of 1 corresponds to ±4.096V range

# Select the input channel to read (e.g., A0)
channel = AnalogIn(ads, ADS.P0)

# Voltage divider parameters
R1 = 330000  # 330kΩ resistor
R2 = 100000  # 100kΩ resistor

# Divider factor
divider_ratio = R2 / (R1 + R2)  

# Measurments for calibration
battery_v = 13.1
detected_v = 13.05

calibration_factor = detected_v / battery_v

def read_battery_voltage():
    # Read raw ADC voltage
    adc_voltage = channel.voltage  # Voltage at the ADC pin (post-divider)

    # Calculate the actual battery voltage
    battery_voltage = (adc_voltage / divider_ratio) * calibration_factor

    return battery_voltage

# Dummy read. After boot, the first read is wrong.
channel.voltage
time.sleep(0.1)

# In this way, you need to call this sript with crontab.
if __name__ == "__main__":
    battery_voltage = read_battery_voltage()
    print(f"Battery Voltage: {battery_voltage:.2f} V")
    log_message(f"battery.py - Battery Voltage: {battery_voltage:.2f} V")
    # Separate log for battery data. This one doesn't rotate and keeps all the data.
    with open(batt_log_file, 'a') as log:
        log.write(f"{datetime.now().strftime('%d-%b-%Y %H:%M:%S')}, {battery_voltage:.2f} V\n")

# Without crontab use main loop and sleep... 
#print("Measuring battery voltage. Press Ctrl+C to stop.")
#try:
#    while True:
#        battery_voltage = read_battery_voltage()
#        print(f"Battery Voltage: {battery_voltage:.2f} V")
#        time.sleep(1)  # Wait 1 second between readings
#except KeyboardInterrupt:
#    print("\nMeasurement stopped.")
